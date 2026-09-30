# Burgas Navigator — Project Context

## Project Overview

Burgas Navigator is a Flutter mobile app that provides location/navigation-oriented assistance for Burgas, with Bulgarian, English and German UI/voice support.

Repository: Ivo760407/burgas-navigator
Default branch: main
Current app version: 1.0.0+1

## Current Status

### Already present

- Flutter application in `lib/main.dart`.
- Language selection: BG / EN / DE.
- Device location via Geolocator.
- Reverse geocoding via Geocoding.
- Map display via flutter_map + OpenStreetMap tiles.
- Speech input dependency: speech_to_text.
- Local/device TTS via flutter_tts as fallback.
- Cloud TTS client path via `CLOUD_TTS_URL`.
- Cloud TTS backend in `backend/cloud-run/`.
- Cloud backend uses Google Cloud Text-to-Speech through a server-side access token.
- No Google service-account JSON is required in the Flutter app.

### Currently working on

Secure production exposure of the `POST /tts` endpoint before making the service publicly usable.

### Next tasks

1. Protect the public TTS endpoint with Firebase App Check verified by Cloud Run.
2. Keep abuse protection/rate limiting.
3. Keep Google Cloud credentials server-side only.
4. Deploy Cloud Run with a dedicated service account.
5. Configure the Flutter build with `--dart-define=CLOUD_TTS_URL=...`.
6. Test BG/EN/DE cloud audio and fallback behavior.
7. Verify that no secret, API key or service-account JSON is present in source, Git history or APK.

## Architecture

```
Flutter app
   |
   | HTTPS POST /tts + Firebase App Check token
   v
Cloud Run
   |
   | Firebase Admin verifies App Check
   | Google-authenticated server-to-server request
   v
Google Cloud Text-to-Speech
   |
   v
MP3
   |
   v
Flutter AudioPlayer
```

Important: Google Cloud credentials must never be shipped inside the APK and must never be committed to GitHub.

## Flutter Application

Main entry point:

- `lib/main.dart`

Relevant packages:

- `flutter_tts`
- `audioplayers`
- `http`
- `geolocator`
- `geocoding`
- `flutter_map`
- `latlong2`
- `speech_to_text`

Cloud TTS configuration:

```dart
static const String _cloudTtsUrl =
    String.fromEnvironment('CLOUD_TTS_URL');
```

The app sends:

```json
{
  "text": "...",
  "language": "bg"
}
```

to the configured cloud endpoint.

If cloud TTS is unavailable or not configured, the app falls back to local `flutter_tts`.

## Cloud TTS

Location:

- `backend/cloud-run/server.js`
- `backend/cloud-run/package.json`
- `backend/cloud-run/README.md`

Endpoints currently implemented:

- GET `/health`
- POST `/tts`

Request:

```json
{
  "text": "Вие сте в Бургас, на улица Александровска 1.",
  "language": "bg"
}
```

Limits currently in code:

- Maximum text length: 300 characters.
- Supported languages: `bg`, `en`, `de`.
- Successful response: `audio/mpeg`.
- Errors do not expose Google credentials.

Configured Google Cloud voices:

- BG: `bg-BG-Chirp3-HD-Achernar`
- EN: `en-US-Chirp3-HD-Achernar`
- DE: `de-DE-Chirp3-HD-Achernar`

The backend uses `google-auth-library` and obtains a Google access token server-side. It also uses `firebase-admin` to verify Firebase App Check tokens.

## Cloud Run

The backend is designed to run on Cloud Run.

Expected production model:

- Dedicated service account attached to Cloud Run.
- No service-account JSON key in repository.
- No Google API key in Flutter.
- Cloud Run should not be unnecessarily exposed as an unrestricted backend; App Check is enforced at the application layer.

## Firebase App Check / Protection

Production target:

```
Flutter app
   |
   | HTTPS POST /tts + X-Firebase-AppCheck
   v
Cloud Run
   |
   | Firebase Admin verifies App Check
   v
Google Cloud Text-to-Speech
```

Protection requirements:
- No login is required for the demo experience.
- Flutter obtains a Firebase App Check token automatically.
- Android release builds use Play Integrity; iOS release builds use App Attest.
- Debug builds use the App Check debug provider.
- Cloud Run verifies the App Check token before invoking Google TTS.
- Cloud Run keeps a 30 requests/minute per observed client limit, 8 KB request-body limit and 300-character TTS limit.
- Google credentials remain server-side through the Cloud Run service account.
- App Check is not treated as a secret or absolute anti-abuse guarantee; rate limiting and Google Cloud quotas/budget monitoring remain required.
- Cloud Run should not be an unrestricted public backend.

`CLOUD_TTS_URL` contains only the public HTTPS endpoint and is not a credential.

Firebase platform configuration is project-specific. Generate it after the Firebase project exists. Never add service-account private keys or Google OAuth credentials to the Flutter project.

## Demo / Product Model

The app should let users experience the product before purchase without requiring account creation. The demo/purchase entitlement is separate from backend security: App Check protects the TTS backend and should not decide whether a user has purchased the full version.

## Secrets

NEVER store in this file or repository:

- Google API keys
- Service-account JSON
- Private keys
- OAuth tokens
- Access tokens
- Passwords
- Production credentials

Secrets belong in Google Cloud Secret Manager or the appropriate server-side credential mechanism.

## Security Checklist

- [ ] No Google API key in Flutter source.
- [ ] No service-account JSON in repository.
- [ ] No credentials in `--dart-define`.
- [ ] Cloud Run uses a dedicated service account.
- [ ] Firebase App Check is configured and enforced before public release.
- [ ] Rate limiting / abuse protection enabled.
- [ ] Text length and language validation enabled.
- [ ] Generic client-facing error messages.
- [ ] Cloud Run ingress/access policy reviewed.
- [ ] Git history checked for accidentally committed secrets.
- [ ] Release APK inspected for credentials/endpoints that should remain private.

## API Contract

### GET /health

Purpose: health check.

Expected response:

```json
{
  "ok": true
}
```

### POST /tts

Request:

```json
{
  "text": "string, 1-300 characters",
  "language": "bg | en | de"
}
```

Success:

- HTTP 200
- Content-Type: `audio/mpeg`
- Body: MP3 bytes

Validation errors:

- HTTP 400

Backend/TTS failure:

- Current implementation returns HTTP 502 with a generic error.

## Rate Limiting

Cloud Run currently limits each observed client to 30 requests/minute. This is per Cloud Run instance and therefore is not a complete distributed quota. Google Cloud quotas/budget monitoring should also be enabled.

At minimum consider:

- requests per IP/client
- requests per minute
- daily quota
- maximum text length
- concurrent request control
- Google Cloud budget/quota monitoring

## Important Design Decisions

1. Google credentials stay server-side.
2. Flutter receives only generated audio.
3. Local TTS remains a fallback.
4. Cloud TTS URL is supplied at build time through `CLOUD_TTS_URL`.
5. Production TTS traffic is protected by Firebase App Check and Cloud Run verification.
6. Do not put secrets in GitHub, Flutter assets, Dart constants, or APK resources.

## Git Workflow

Before significant production changes:

1. Inspect current `main`.
2. Make a focused change.
3. Commit with a clear message.
4. Review the diff.
5. Test before deployment.

Avoid destructive history rewrites unless explicitly requested.

## Known Problems / Open Questions

- Firebase project and Android/iOS App Check configuration still need to be created and tested.
- Production Cloud Run deployment has not yet been documented with exact project/service names.
- Need to verify Play Integrity/App Attest in release builds.
- Need to verify Cloud Run ingress/access policy and Google TTS IAM permissions.

## Deployment Checklist

### Google Cloud

- [ ] Select/create Google Cloud project.
- [ ] Enable Cloud Text-to-Speech API.
- [ ] Create dedicated service account.
- [ ] Grant only required permissions.
- [ ] Deploy `backend/cloud-run` to Cloud Run.
- [ ] Confirm Cloud Run can authenticate to Text-to-Speech.
- [ ] Configure Cloud Run access/ingress for the chosen gateway architecture.
- [ ] Create API Gateway.
- [ ] Configure `POST /tts` route.
- [ ] Add quotas/rate limits/abuse controls.
- [ ] Test gateway -> Cloud Run -> Google TTS.

### Flutter

- [ ] Set production `CLOUD_TTS_URL` via `--dart-define`.
- [ ] Configure Firebase Android/iOS app files for the project.
- [ ] Build release APK.
- [ ] Test BG.
- [ ] Test EN.
- [ ] Test DE.
- [ ] Test offline/failure fallback.
- [ ] Inspect APK/build configuration for secrets.

## Do Not Do

- Do not put Google service-account JSON in the Flutter project.
- Do not put Google API keys in Dart code.
- Do not commit credentials to GitHub.
- Do not make an unrestricted public `/tts` endpoint the final production architecture.
- Do not put long-lived backend secrets in `CLOUD_TTS_URL`.
- Do not expose detailed Google API errors to the mobile client.

## Instructions for the Next Chat

Start by reading this file.

Then inspect the relevant current files in the repository before changing anything.

Current priority:

1. Secure `/tts` with Firebase App Check.
2. Configure Firebase/Play Integrity/App Attest.
3. Keep rate limiting/abuse protection.
4. Verify Cloud Run service-account permissions.
5. Update/document deployment commands.
6. Test the Flutter cloud TTS path.
7. Only then prepare the production release.

Never request or store secrets in this context file.

## Change Log

### 2026-09-30

- Created this project context file from the current repository state.
- Confirmed repository default branch is `main`.
- Confirmed Cloud TTS backend exists under `backend/cloud-run/`.
- Confirmed Flutter already supports `CLOUD_TTS_URL` and local TTS fallback.
- Switched TTS protection design from API Gateway/API key to Firebase App Check + Cloud Run.
- Added Firebase App Check verification to the Cloud Run TTS endpoint.
- Removed API Gateway/API-key configuration from the security branch.
