import http from 'node:http';
import { GoogleAuth } from 'google-auth-library';

const port = Number(process.env.PORT || 8080);
const maxTextLength = 300;
const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-platform'],
});

const voices = {
  bg: 'bg-BG-Chirp3-HD-Achernar',
  en: 'en-US-Chirp3-HD-Achernar',
  de: 'de-DE-Chirp3-HD-Achernar',
};

const languageCodes = {
  bg: 'bg-BG',
  en: 'en-US',
  de: 'de-DE',
};

function sendJson(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(body));
}

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const raw = Buffer.concat(chunks).toString('utf8');
  if (!raw) return {};
  return JSON.parse(raw);
}

async function synthesize(text, language) {
  const client = await auth.getClient();
  const tokenResult = await client.getAccessToken();
  const accessToken =
      typeof tokenResult === 'string' ? tokenResult : tokenResult?.token;

  if (!accessToken) {
    throw new Error('Google Cloud access token unavailable');
  }

  const response = await fetch(
    'https://texttospeech.googleapis.com/v1/text:synthesize',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        input: { text },
        voice: {
          languageCode: languageCodes[language],
          name: voices[language],
        },
        audioConfig: {
          audioEncoding: 'MP3',
          speakingRate: 0.95,
          pitch: 0,
        },
      }),
    },
  );

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`Google TTS failed: ${response.status} ${details}`);
  }

  const data = await response.json();
  if (!data.audioContent) throw new Error('Google TTS returned no audio');
  return Buffer.from(data.audioContent, 'base64');
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    return sendJson(res, 200, { ok: true });
  }

  if (req.method !== 'POST' || req.url !== '/tts') {
    return sendJson(res, 404, { error: 'Not found' });
  }

  try {
    const body = await readJson(req);
    const text = typeof body.text === 'string' ? body.text.trim() : '';
    const language = typeof body.language === 'string' ? body.language : 'bg';

    if (!text || text.length > maxTextLength) {
      return sendJson(res, 400, {
        error: `Text must contain 1-${maxTextLength} characters.`,
      });
    }

    if (!languageCodes[language]) {
      return sendJson(res, 400, { error: 'Unsupported language.' });
    }

    const audio = await synthesize(text, language);
    res.writeHead(200, {
      'Content-Type': 'audio/mpeg',
      'Content-Length': audio.length,
      'Cache-Control': 'no-store',
    });
    return res.end(audio);
  } catch (error) {
    console.error(error);
    return sendJson(res, 502, { error: 'Cloud TTS request failed.' });
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Cloud TTS listening on ${port}`);
});
