import http from 'node:http';
import { GoogleAuth } from 'google-auth-library';
import { initializeApp } from 'firebase-admin/app';
import { getAppCheck } from 'firebase-admin/app-check';

const port = Number(process.env.PORT || 8080);
const maxTextLength = 300;
const maxBodyBytes = 8 * 1024;
const windowMs = 60_000;
const maxRequests = 30;
const buckets = new Map();
const auth = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
initializeApp();

const voices = { bg: 'bg-BG-Chirp3-HD-Achernar', en: 'en-US-Chirp3-HD-Achernar', de: 'de-DE-Chirp3-HD-Achernar' };
const languageCodes = { bg: 'bg-BG', en: 'en-US', de: 'de-DE' };

function sendJson(res, status, body, headers = {}) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...headers });
  res.end(JSON.stringify(body));
}
function clientKey(req) {
  const forwarded = req.headers['x-forwarded-for'];
  return typeof forwarded === 'string' && forwarded.trim() ? forwarded.split(',')[0].trim() : req.socket.remoteAddress || 'unknown';
}
function allowed(req) {
  const now = Date.now(), key = clientKey(req);
  let bucket = buckets.get(key);
  if (!bucket || now - bucket.startedAt >= windowMs) {
    buckets.set(key, { startedAt: now, count: 1 }); return true;
  }
  bucket.count += 1; return bucket.count <= maxRequests;
}
setInterval(() => {
  const cutoff = Date.now() - windowMs * 2;
  for (const [key, bucket] of buckets) if (bucket.startedAt < cutoff) buckets.delete(key);
}, windowMs).unref();

async function verifyAppCheck(req) {
  const token = req.headers['x-firebase-appcheck'];
  if (typeof token !== 'string' || !token.trim()) return null;
  try {
    return await getAppCheck().verifyToken(token.trim());
  } catch (_) {
    return null;
  }
}

async function readJson(req) {
  const chunks = []; let total = 0;
  for await (const chunk of req) {
    total += chunk.length;
    if (total > maxBodyBytes) { const e = new Error('body too large'); e.code = 'BODY_TOO_LARGE'; throw e; }
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString('utf8');
  return raw ? JSON.parse(raw) : {};
}

async function synthesize(text, language) {
  const client = await auth.getClient();
  const tokenResult = await client.getAccessToken();
  const accessToken = typeof tokenResult === 'string' ? tokenResult : tokenResult?.token;
  if (!accessToken) throw new Error('Google Cloud access token unavailable');
  const response = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      input: { text },
      voice: { languageCode: languageCodes[language], name: voices[language] },
      audioConfig: { audioEncoding: 'MP3', speakingRate: 0.95, pitch: 0 },
    }),
  });
  if (!response.ok) throw new Error(`Google TTS failed: ${response.status} ${await response.text()}`);
  const data = await response.json();
  if (!data.audioContent) throw new Error('Google TTS returned no audio');
  return Buffer.from(data.audioContent, 'base64');
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/health') return sendJson(res, 200, { ok: true });
  if (req.method !== 'POST' || req.url !== '/tts') return sendJson(res, 404, { error: 'Not found' });

  const appCheck = await verifyAppCheck(req);
  if (!appCheck) return sendJson(res, 401, { error: 'App verification failed.' });
  if (!allowed(req)) return sendJson(res, 429, { error: 'Too many requests. Please try again later.' }, { 'Retry-After': '60' });

  try {
    const body = await readJson(req);
    const text = typeof body.text === 'string' ? body.text.trim() : '';
    const language = typeof body.language === 'string' ? body.language : 'bg';
    if (!text || text.length > maxTextLength) return sendJson(res, 400, { error: `Text must contain 1-${maxTextLength} characters.` });
    if (!languageCodes[language]) return sendJson(res, 400, { error: 'Unsupported language.' });
    const audio = await synthesize(text, language);
    res.writeHead(200, { 'Content-Type': 'audio/mpeg', 'Content-Length': audio.length, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    return res.end(audio);
  } catch (error) {
    if (error?.code === 'BODY_TOO_LARGE') return sendJson(res, 413, { error: 'Request body is too large.' });
    if (error instanceof SyntaxError) return sendJson(res, 400, { error: 'Invalid JSON.' });
    console.error(error); return sendJson(res, 502, { error: 'Cloud TTS request failed.' });
  }
});
server.listen(port, '0.0.0.0', () => console.log(`Cloud TTS listening on ${port}`));