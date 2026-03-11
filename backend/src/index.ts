import express from 'express';
import cors from 'cors';
import Anthropic from '@anthropic-ai/sdk';

const app = express();
const client = new Anthropic(); // ANTHROPIC_API_KEY 환경변수 자동 사용

app.use(cors());
app.use(express.json());

// 간단한 인메모리 레이트 리미터: IP당 분당 20회
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

// 오래된 레이트 리밋 항목 5분마다 정리
setInterval(() => {
  const now = Date.now();
  for (const [ip, entry] of rateLimitMap.entries()) {
    if (now > entry.resetAt) rateLimitMap.delete(ip);
  }
}, 5 * 60_000);

// 지원 언어 목록 (앱과 동기화)
const SUPPORTED_LANGUAGES = new Set([
  '한국어', 'English', '日本語', '中文', 'Español', 'Français', 'Deutsch',
]);

app.post('/api/lookup', async (req, res) => {
  const ip = req.ip ?? 'unknown';

  if (!checkRateLimit(ip)) {
    return res.status(429).json({ error: 'rate_limit' });
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
  if (exampleLanguage !== undefined && (typeof exampleLanguage !== 'string' || !SUPPORTED_LANGUAGES.has(exampleLanguage))) {
    return res.status(400).json({ error: 'invalid_request', message: 'invalid exampleLanguage' });
  }

  const trimmedWord = word.trim().slice(0, 100);
  // exampleLanguage 미지정 시 입력 단어와 같은 언어로 자동 처리
  const exampleLang = typeof exampleLanguage === 'string' ? exampleLanguage : 'the same language as the input word';

  try {
    const response = await client.messages.create({
      model: 'claude-opus-4-6',
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

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

const PORT = parseInt(process.env.PORT ?? '3000', 10);
app.listen(PORT, () => {
  console.log(`Word Bank backend running on port ${PORT}`);
});
