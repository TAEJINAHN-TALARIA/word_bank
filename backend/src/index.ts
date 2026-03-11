import express from 'express';
import cors from 'cors';
import Anthropic from '@anthropic-ai/sdk';
import admin from 'firebase-admin';

const app = express();
const client = new Anthropic();

app.use(cors());
app.use(express.json());

// ─── Firebase Admin 초기화 (FIREBASE_SERVICE_ACCOUNT 환경변수가 있을 때만) ───
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

// ─── Firebase 토큰 검증 ───
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

// ─── Firestore 월별 사용량 확인 및 증가 ───
async function checkAndIncrementUsage(
  uid: string,
): Promise<{ allowed: boolean; count: number; limit: number }> {
  const now = new Date();
  const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  const usageRef = admin
    .firestore()
    .collection('users')
    .doc(uid)
    .collection('usage')
    .doc(monthKey);

  return admin.firestore().runTransaction(async (t) => {
    const doc = await t.get(usageRef);
    const currentCount = (doc.data()?.count as number) ?? 0;

    if (currentCount >= FREE_MONTHLY_LIMIT) {
      return { allowed: false, count: currentCount, limit: FREE_MONTHLY_LIMIT };
    }

    t.set(
      usageRef,
      { count: currentCount + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );
    return { allowed: true, count: currentCount + 1, limit: FREE_MONTHLY_LIMIT };
  });
}

// ─── 간단한 인메모리 레이트 리미터 (IP당 분당 20회) ───
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

// ─── 지원 언어 목록 ───
const SUPPORTED_LANGUAGES = new Set([
  '한국어', 'English', '日本語', '中文', 'Español', 'Français', 'Deutsch',
]);

// ─── POST /api/lookup ───
app.post('/api/lookup', async (req, res) => {
  const ip = req.ip ?? 'unknown';
  if (!checkRateLimit(ip)) {
    return res.status(429).json({ error: 'rate_limit' });
  }

  // Auth 검증
  const userInfo = await verifyToken(req.headers.authorization);
  if (firebaseEnabled && !userInfo) {
    return res.status(401).json({ error: 'auth_required' });
  }

  // 무료 사용량 체크
  let usageResult: { allowed: boolean; count: number; limit: number } | null = null;
  if (firebaseEnabled && userInfo && !userInfo.isPremium) {
    usageResult = await checkAndIncrementUsage(userInfo.uid);
    if (!usageResult.allowed) {
      return res.status(429).json({
        error: 'quota_exceeded',
        count: usageResult.count,
        limit: usageResult.limit,
      });
    }
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

  // 무료 → Haiku (저비용), 프리미엄 → Opus (고품질)
  const model =
    firebaseEnabled && userInfo?.isPremium
      ? 'claude-opus-4-6'
      : 'claude-haiku-4-5-20251001';

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
            `{"word":"canonical spelling","phonetic":"IPA notation or null","meanings":[{"pos":"part of speech","definition":"...","example":"...or null","synonyms":["..."]}]}\n\n` +
            `Rules:\n` +
            `- Detect the input word's language automatically\n` +
            `- Provide up to 2 meanings\n` +
            `- definition: write in ${language}\n` +
            `- example: write in ${exampleLang}, or null if unavailable\n` +
            `- synonyms: write in ${exampleLang}, up to 3 items, can be empty []\n` +
            `- If the word/phrase does not exist, respond with: {"error":"not_found"}`,
        },
      ],
    });

    const text =
      response.content[0].type === 'text' ? response.content[0].text.trim() : '';

    let result: unknown;
    try {
      result = JSON.parse(text);
    } catch {
      console.error('JSON parse failed. Raw response:', text);
      return res.status(500).json({ error: 'parse_error' });
    }

    // 사용량 헤더 추가
    if (usageResult) {
      res.setHeader('X-Usage-Count', usageResult.count.toString());
      res.setHeader('X-Usage-Limit', usageResult.limit.toString());
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

// ─── GET /api/usage ───
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

// ─── RevenueCat 웹훅 이벤트 타입 ───
type RevenueCatEventType =
  | 'INITIAL_PURCHASE'
  | 'RENEWAL'
  | 'CANCELLATION'
  | 'UNCANCELLATION'
  | 'EXPIRATION'
  | 'REFUND'
  | 'NON_RENEWING_PURCHASE'
  | 'SUBSCRIPTION_PAUSED'
  | 'TRANSFER';

interface RevenueCatWebhookPayload {
  api_version: string;
  event: {
    type: RevenueCatEventType;
    app_user_id: string;        // Purchases.logIn(uid)으로 설정한 Firebase UID
    expiration_at_ms: number | null;
    product_id: string;
    environment: 'PRODUCTION' | 'SANDBOX';
  };
}

// ─── POST /api/revenuecat-webhook ───
// RevenueCat Dashboard → Project Settings → Integrations → Webhooks
// Authorization Header 값을 REVENUECAT_WEBHOOK_AUTH_HEADER 환경변수에 설정
app.post('/api/revenuecat-webhook', async (req, res) => {
  // 웹훅 인증 헤더 검증
  const expectedAuth = process.env.REVENUECAT_WEBHOOK_AUTH_HEADER;
  if (expectedAuth && req.headers.authorization !== `Bearer ${expectedAuth}`) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  if (!firebaseEnabled) {
    return res.status(503).json({ error: 'firebase_not_configured' });
  }

  const payload = req.body as RevenueCatWebhookPayload;
  const event = payload?.event;
  if (!event?.app_user_id || !event?.type) {
    return res.status(400).json({ error: 'invalid_payload' });
  }

  const uid = event.app_user_id;
  const userRef = admin.firestore().collection('users').doc(uid);

  try {
    switch (event.type) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'UNCANCELLATION': {
        // 구독 활성화 또는 갱신
        const expiresAt = event.expiration_at_ms
          ? admin.firestore.Timestamp.fromMillis(event.expiration_at_ms)
          : null;
        await userRef.set(
          {
            isPremium: true,
            ...(expiresAt && { premiumExpiresAt: expiresAt }),
          },
          { merge: true },
        );
        console.log(`[RC Webhook] ${event.type}: uid=${uid}, expires=${event.expiration_at_ms}`);
        break;
      }

      case 'EXPIRATION':
      case 'REFUND':
        // 구독 만료 또는 환불 → 프리미엄 즉시 해제
        await userRef.set({ isPremium: false }, { merge: true });
        console.log(`[RC Webhook] ${event.type}: uid=${uid} → premium revoked`);
        break;

      case 'CANCELLATION':
        // 구독 취소 예약 (만료일까지는 활성 유지)
        // RevenueCat이 만료일에 EXPIRATION 이벤트를 전송하므로 별도 처리 불필요
        console.log(`[RC Webhook] CANCELLATION: uid=${uid} (active until expiry)`);
        break;

      default:
        // TRANSFER, SUBSCRIPTION_PAUSED 등 기타 이벤트는 무시
        break;
    }

    return res.json({ received: true });
  } catch (err) {
    console.error('[RC Webhook] Processing error:', err);
    // 5xx 응답 시 RevenueCat이 최대 5회 재시도
    return res.status(500).json({ error: 'server_error' });
  }
});

// ─── GET /health ───
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', firebase: firebaseEnabled });
});

const PORT = parseInt(process.env.PORT ?? '3000', 10);
app.listen(PORT, () => {
  console.log(`Word Bank backend running on port ${PORT}`);
});
