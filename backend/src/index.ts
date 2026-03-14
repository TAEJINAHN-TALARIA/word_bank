import express from 'express';
import cors from 'cors';
import Anthropic from '@anthropic-ai/sdk';
import admin from 'firebase-admin';

const app = express();
const client = new Anthropic();

app.use(cors());
app.use(express.json());

// Firebase Admin 초기화 (FIREBASE_SERVICE_ACCOUNT 환경변수가 있을 때만)
let firebaseEnabled = false;
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
if (serviceAccountJson) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
    });
    firebaseEnabled = true;
    console.log('Firebase Admin initialized');
  } catch (e) {
    console.error('Firebase Admin init failed:', e);
  }
} else {
  console.warn('FIREBASE_SERVICE_ACCOUNT not set — running without auth (dev mode)');
}

const FREE_MONTHLY_LIMIT = parseInt(process.env.FREE_MONTHLY_LIMIT ?? '50', 10);

// Firebase 토큰 검증
async function verifyToken(
  authHeader: string | undefined,
): Promise<{ uid: string; isPremium: boolean } | null> {
  if (!firebaseEnabled) return null;
  if (!authHeader?.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7);
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    const uid = decoded.uid;
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    const data = userDoc.data();
    const isPremium =
      data?.isPremium === true &&
      (data?.premiumExpiresAt?.toDate() ?? new Date(0)) > new Date();
    return { uid, isPremium };
  } catch {
    return null;
  }
}


// 간단한 인메모리 rate limiter (IP당 분당 20회)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(ip);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + 60_000 });
    return true;
  }
  if (entry.count >= 20) return false;
  entry.count++;
  return true;
}

setInterval(() => {
  const now = Date.now();
  for (const [ip, entry] of rateLimitMap.entries()) {
    if (now > entry.resetAt) rateLimitMap.delete(ip);
  }
}, 5 * 60_000);

// 지원 언어 목록
const SUPPORTED_LANGUAGES = new Set([
  '한국어',
  'English',
  '中文',
  '日本語',
  'Español',
  'Français',
  'Deutsch',
]);

// Firestore 캐시 문서 ID 생성
// 허용 문자 외 모두 '_'로 치환, 최대 500자
function buildCacheId(word: string, language: string, exampleLang: string): string {
  return `${word.toLowerCase()}_${language}_${exampleLang}`
    .replace(/[^a-zA-Z0-9가-힣ぁ-んァ-ン一-龯\-_]/g, '_')
    .slice(0, 500);
}

// POST /api/lookup
app.post('/api/lookup', async (req, res) => {
  const ip = req.ip ?? 'unknown';
  if (!checkRateLimit(ip)) {
    return res.status(429).json({ error: 'rate_limit' });
  }

  // 인증 확인
  const userInfo = await verifyToken(req.headers.authorization);
  if (firebaseEnabled && !userInfo) {
    return res.status(401).json({ error: 'auth_required' });
  }

  const { word, language, exampleLanguage } = req.body as {
    word?: unknown;
    language?: unknown;
    exampleLanguage?: unknown;
  };

  if (!word || typeof word !== 'string' || word.trim().length === 0) {
    return res.status(400).json({ error: 'invalid_request', message: 'word is required' });
  }
  if (!language || typeof language !== 'string' || !SUPPORTED_LANGUAGES.has(language)) {
    return res.status(400).json({ error: 'invalid_request', message: 'invalid language' });
  }
  if (
    exampleLanguage !== undefined &&
    (typeof exampleLanguage !== 'string' || !SUPPORTED_LANGUAGES.has(exampleLanguage))
  ) {
    return res.status(400).json({ error: 'invalid_request', message: 'invalid exampleLanguage' });
  }

  const trimmedWord = word.trim().slice(0, 100);
  const exampleLang =
    typeof exampleLanguage === 'string'
      ? exampleLanguage
      : 'the same language as the input word';

  // No lookup quota check (quota is enforced on save)

  // ── Firestore 공유 캐시 확인 ─────────────────────────────────────────────
  // 같은 단어+언어 조합을 다른 유저가 이미 조회했다면 Claude API를 호출하지 않음
  const cacheId = buildCacheId(trimmedWord, language, exampleLang);
  if (firebaseEnabled) {
    try {
      const cacheDoc = await admin.firestore().collection('word_cache').doc(cacheId).get();
      if (cacheDoc.exists) {
        console.log(`Cache hit: ${cacheId}`);
        return res.json(cacheDoc.data()!.payload);
      }
    } catch (e) {
      // 캐시 조회 실패는 치명적이지 않으므로 API 호출로 폴백
      console.error('Cache read failed, falling back to API:', e);
    }
  }

  // Always use Haiku for all plans
  const model = 'claude-haiku-4-5-20251001';

  try {
    const response = await client.messages.create({
      model,
      max_tokens: 1024,
      system:
        'You are a multilingual dictionary API. Always respond with valid JSON only. ' +
        'No markdown, no code blocks, no explanation — just the raw JSON object.',
      messages: [
        {
          role: 'user',
          content:
            `Look up the word or phrase: "${trimmedWord}"\n\n` +
            `If the word exists, respond with this JSON:\n` +
            `{"word":"canonical spelling","phonetic":"IPA notation or null","meanings":[{"pos":"part of speech","definitions":["..."],"examples":["..."]}],"media":{"photos":[],"youtube":[]}}\n\n` +
            `Rules:\n` +
            `- Detect the input word's language automatically\n` +
            `- Provide up to 2 meanings\n` +
            `- definitions: write in ${language}, up to 3 items\n` +
            `- examples: write in ${exampleLang}, exactly 1 full sentence (18–30 words) showing real-world, natural usage with clear context\n` +
            `  * include a plausible setting, speaker, or situation\n` +
            `  * avoid generic templates ("I like...", "This is...") and avoid dictionary-style fragments\n` +
            `  * ensure the target word/phrase appears once and feels idiomatic\n` +
            `  * if no good example exists, return []\n` +
            `- media.photos and media.youtube must be arrays; leave them empty []\n` +
            `- If the word/phrase does not exist, respond with: {"error":"not_found"}`,
        },
      ],
    });

    const raw =
      response.content[0].type === 'text' ? response.content[0].text.trim() : '';
    // 마크다운 코드블록 제거 (```json ... ``` 또는 ``` ... ```)
    const text = raw.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '').trim();

    let result: unknown;
    try {
      result = JSON.parse(text);
    } catch {
      console.error('JSON parse failed. Raw response:', text);
      return res.status(500).json({ error: 'parse_error' });
    }

    // not_found는 캐시하지 않음 (오타나 존재하지 않는 단어)
    const parsed = result as Record<string, unknown>;
    if (firebaseEnabled && parsed.error !== 'not_found') {
      admin
        .firestore()
        .collection('word_cache')
        .doc(cacheId)
        .set({
          payload: result,
          word: trimmedWord.toLowerCase(),
          language,
          exampleLanguage: exampleLang,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        })
        .catch((e: unknown) => console.error('Cache write failed:', e));
    }

    return res.json(result);
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) {
      return res.status(429).json({ error: 'rate_limit' });
    }
    if (error instanceof Anthropic.AuthenticationError) {
      console.error('Authentication error: check ANTHROPIC_API_KEY');
      return res.status(500).json({ error: 'server_error' });
    }
    console.error('Lookup error:', error);
    return res.status(500).json({ error: 'server_error' });
  }
});

// GET /api/usage
app.get('/api/usage', async (req, res) => {
  if (!firebaseEnabled) {
    return res.json({ count: 0, limit: FREE_MONTHLY_LIMIT, isPremium: false });
  }

  const userInfo = await verifyToken(req.headers.authorization);
  if (!userInfo) {
    return res.status(401).json({ error: 'auth_required' });
  }

  if (userInfo.isPremium) {
    return res.json({ count: 0, limit: -1, isPremium: true });
  }

  const now = new Date();
  const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  const usageDoc = await admin
    .firestore()
    .collection('users')
    .doc(userInfo.uid)
    .collection('usage')
    .doc(monthKey)
    .get();

  const count = (usageDoc.data()?.count as number) ?? 0;
  return res.json({ count, limit: FREE_MONTHLY_LIMIT, isPremium: false });
});

// POST /api/webhook/revenuecat
interface RevenueCatWebhookPayload {
  api_version: string;
  event: {
    type: string;
    app_user_id: string;
    expiration_at_ms: number | null;
    product_id: string;
    store: string;
    environment: string;
  };
}

app.post('/api/webhook/revenuecat', async (req, res) => {
  if (!firebaseEnabled) {
    return res.status(503).json({ error: 'auth_not_configured' });
  }

  const secret = process.env.REVENUECAT_WEBHOOK_SECRET;
  if (!secret) {
    console.error('REVENUECAT_WEBHOOK_SECRET not configured — webhook rejected');
    return res.status(503).json({ error: 'webhook_not_configured' });
  }
  if (req.headers['authorization'] !== secret) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const { event } = req.body as RevenueCatWebhookPayload;
  if (!event?.type || !event?.app_user_id) {
    return res.status(400).json({ error: 'invalid_payload' });
  }

  const uid = event.app_user_id;
  const expiresAt = event.expiration_at_ms ? new Date(event.expiration_at_ms) : null;
  const userRef = admin.firestore().collection('users').doc(uid);

  try {
    switch (event.type) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
        await userRef.set({
          isPremium: true,
          premiumExpiresAt: expiresAt ? admin.firestore.Timestamp.fromDate(expiresAt) : null,
          lastWebhookEvent: event.type,
          lastWebhookAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        break;

      case 'EXPIRATION':
      case 'REFUND':
      case 'BILLING_ISSUE':
        await userRef.set({
          isPremium: false,
          premiumExpiresAt: admin.firestore.FieldValue.delete(),
          lastWebhookEvent: event.type,
          lastWebhookAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        break;

      case 'CANCELLATION':
        // 구독 취소: 만료일까지는 프리미엄 유지, 갱신만 중단
        await userRef.set({
          lastWebhookEvent: event.type,
          lastWebhookAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        break;

      default:
        console.log('Unhandled RevenueCat event:', event.type);
    }
  } catch (err) {
    console.error('Webhook Firestore update failed:', err);
    return res.status(500).json({ error: 'server_error' });
  }

  return res.json({ received: true });
});

// GET /health
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', firebase: firebaseEnabled });
});

const PORT = parseInt(process.env.PORT ?? '3000', 10);
app.listen(PORT, () => {
  console.log(`Word Bank backend running on port ${PORT}`);
});
