# Burgas Navigator Cloud TTS

This HTTP service generates natural-sounding speech with Google Cloud Text-to-Speech. Google credentials stay on the server and are never included in the Flutter APK.

## Endpoints

- `GET /health` — basic health check.
- `POST /tts` — returns generated audio as `audio/mpeg`.

Request body:

```json
{
  "text": "Вие сте в Сливен.",
  "language": "bg"
}
```

Supported language values: `bg`, `en`, `de`. The service limits text to 300 characters.

## Google Cloud setup required

1. Create or select a Google Cloud project.
2. Enable billing for the project. Google requires a billing account even if usage remains within a free quota.
3. Enable the **Cloud Text-to-Speech API**.
4. Create a dedicated runtime service account and grant only the permissions needed to call the Text-to-Speech API.
5. Deploy this directory to Cloud Run using the included `Dockerfile`; attach the service account to the Cloud Run service. Do not upload a service-account JSON key.
6. Put a protected API Gateway or equivalent front door in front of `/tts`, configure authentication and quotas/rate limits, and require authenticated invocation of the Cloud Run backend. Do not leave an unrestricted public TTS endpoint.
7. Test `GET /health` and a `POST /tts` request for Bulgarian, English and German.
8. Configure the deployed HTTPS endpoint as the GitHub repository variable `CLOUD_TTS_URL` so the Android workflow can pass it to Flutter as `--dart-define=CLOUD_TTS_URL=...`.

Google Cloud credentials, API keys, service-account files and access tokens must never be added to this repository, GitHub workflow variables, Flutter code or the APK. Only the public HTTPS endpoint URL belongs in `CLOUD_TTS_URL`.

## Voice selection

The server currently selects Google Cloud Chirp 3 HD voices for Bulgarian, English and German. Voice names are configured in `server.js`. The Flutter app tries cloud audio first and falls back to the phone's local TTS if the endpoint is not configured or the request fails.

## Important limitation

The backend source is prepared in this repository, but the cloud voice is not active in the app until the Cloud Run service is deployed, the endpoint is protected, and `CLOUD_TTS_URL` is configured. Deployment requires access to the Google Cloud project; no credentials are stored in this repository.
