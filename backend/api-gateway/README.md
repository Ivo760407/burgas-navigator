# Protecting the Cloud TTS endpoint

The repository now contains an API Gateway OpenAPI spec and server-side abuse protection.

## What is protected

- API Gateway requires an API key for POST /tts.
- Cloud Run limits each observed client address to 30 requests per minute.
- Cloud Run rejects request bodies over 8 KB.
- TTS text remains limited to 300 characters.
- Google credentials stay server-side through the Cloud Run service account.
- Client-facing errors remain generic.

## Important: API key is not a secret

An API key used by a mobile app can be extracted from the APK. It is therefore used for API Gateway consumer identification and quota/abuse control, not as a high-trust secret.

Do not put Google service-account keys, OAuth secrets, or other long-lived credentials in the Flutter app.

## Google Cloud deployment

Replace CLOUD_RUN_URL in backend/api-gateway/openapi.yaml with the HTTPS URL of the deployed Cloud Run service.

Then create/configure API Gateway using the OpenAPI file. The gateway config should use a dedicated Google service account that has permission to invoke the Cloud Run service.

The Cloud Run service should not remain anonymously invokable as the final production state. After the gateway service account is known, grant it Cloud Run Invoker and remove public unauthenticated invocation.

Deployment sequence:
1. Deploy Cloud Run.
2. Create a dedicated gateway service account.
3. Grant that account permission to invoke Cloud Run.
4. Deploy API Gateway with backend/api-gateway/openapi.yaml.
5. Create an API key for the mobile application and restrict it to the gateway API.
6. Enable API quotas and monitoring.
7. Set Flutter CLOUD_TTS_URL to the API Gateway URL.
8. Update Flutter to send the gateway API key. Remember that this key is not a secret.

## Protection layers

Flutter -> API Gateway (API key + quota) -> Cloud Run (service-account invocation + per-client rate limit + body/text limits) -> Google Cloud TTS.

For stronger per-installation/user authentication later, add a real user/device identity mechanism such as Firebase Authentication/App Check or another attested identity layer rather than relying on an APK-embedded secret.
