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

## Run without a server (default)
No hosting needed. Open the app, Settings, Manage API keys, and add your keys one by one (Groq first). They are stored only on the phone and shown as dots. The app then talks to Groq, Tavily, Newsdata, Serp, OpenWeather and Fish Audio directly. Do not put keys in the code or in GitHub. The APK is signed with the fixed key in `frontend/android_overrides/debug.keystore`, so new builds install over the old app and keep your keys.

## Run the backend (optional)
Set the variables from `backend/.env.example` on your host, then `uvicorn app.main:create_app --factory` (or use `backend/Dockerfile`). Put its https address and `ALEX_APP_TOKEN` in the app's Settings → Backend connection.

## Status
Done: onboarding (name, permissions), chat with premium glass orb, voice input (tap the mic or orb) and spoken replies (backend Fish Audio voice, or the phone's voice as fallback), 7-voice picker, AI customization, on-device commands (flashlight, volume, open app, battery, time/date, music keys, camera app, wifi/bluetooth/display/sound settings, maps/navigation, web search, contacts search and dialer, audio recording), backend (chat, key pool with failover, weather/news/search, TTS, STT, memory, admin keys).
Not built yet: wake word "Alex", screenshots, reading notifications aloud, in-app photo capture, recording playback screen, Hindi/Urdu quality depends on the phone's speech services.
