# ALEX AI

Personal voice assistant: Flutter app + Kotlin Android layer + FastAPI backend. See `docs/ARCHITECTURE.md`.

```
.github/workflows/   android-build.yml  backend-ci.yml  deploy-backend.yml
frontend/            Flutter app (lib/core, lib/features/...), Kotlin files in android_overrides/
backend/             FastAPI (app/routers, app/services, app/core), tests/, Dockerfile
docs/                ARCHITECTURE, API, NATIVE_CHANNEL, PERMISSIONS, HANDOFF_PROMPT
```

## Build the APK (no local Flutter needed)
Push to `main` (or run "Android CI/CD" manually). Download **ALEX-AI-release-apk** from the run's Artifacts. The release APK is signed with the debug key, which is fine for installing on your own phone.

## Run the backend
Set the variables from `backend/.env.example` on your host, then `uvicorn app.main:create_app --factory` (or use `backend/Dockerfile`). Put its https address and `ALEX_APP_TOKEN` in the app's Settings → Backend connection.

## Status
Done: onboarding (name, permissions), chat UI with glass orb, on-device commands (flashlight, volume, open app), AI customization, backend (chat, key pool with failover, weather/news/search, TTS, STT, memory, admin keys).
Not built yet: microphone capture and spoken replies in the app, camera, audio recording, contacts, music control, notification reading, wake word "Alex", per-voice avatar screen in the app.
