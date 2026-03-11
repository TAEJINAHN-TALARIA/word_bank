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

// ─── POST /api/verify-purchase (IAP 영수증 검증 후 프리미엄 활성화) ───
app.post('/api/verify-purchase', async (req, res) => {
  if (!firebaseEnabled) {
    return res.status(503).json({ error: 'auth_not_configured' });
  }

  const userInfo = await verifyToken(req.headers.authorization);
  if (!userInfo) {
    return res.status(401).json({ error: 'auth_required' });
  }

  const { platform, receiptData, productId } = req.body as {
    platform?: string;
    receiptData?: string;
    productId?: string;
  };

  if (!platform || !receiptData || !productId) {
    return res.status(400).json({ error: 'invalid_request' });
  }

  // TODO: 프로덕션에서는 Apple/Google 서버에 영수증 검증 요청 필요
  // iOS:     POST https://buy.itunes.apple.com/verifyReceipt
  // Android: Google Play Developer API 사용

  const expiresAt = new Date();
  expiresAt.setMonth(expiresAt.getMonth() + 1);

  await admin.firestore().collection('users').doc(userInfo.uid).set(
    {
      isPremium: true,
      premiumExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      lastPurchase: {
        platform,
        productId,
        purchasedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    },
    { merge: true },
  );

  return res.json({ success: true, isPremium: true });
});

// ─── GET /health ───
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', firebase: firebaseEnabled });
});

const PORT = parseInt(process.env.PORT ?? '3000', 10);
app.listen(PORT, () => {
  console.log(`Word Bank backend running on port ${PORT}`);
});
