# Backend API

All endpoints except `/health` need `Authorization: Bearer <ALEX_APP_TOKEN>` and `X-User-Id: <8-64 chars A-Z a-z 0-9 _ ->`.
Admin endpoints need `Authorization: Bearer <ALEX_ADMIN_TOKEN>`. Run: `uvicorn app.main:create_app --factory`.

| Method | Path | Purpose |
|---|---|---|
| GET | /health | Liveness check (public) |
| POST | /chat `{message}` | Returns `{reply, intent, device_action}`. `device_action` is `null` or a whitelisted action |
| GET | /voices | The 7 voices and whether a Fish Audio voice id is configured |
| POST | /tts `{text, voice?}` | MP3 audio via Fish Audio |
| POST | /stt (multipart `file`, optional `language`) | Text via Groq Whisper |
| GET/PUT | /user/profile | name, persona_preset, persona_custom, voice |
| GET/POST/DELETE | /user/memory, /user/memory/{index} | Per-user remembered facts |
| GET | /admin/keys | Ids, status and counters per provider (never key values) |
| POST | /admin/keys/{provider} `{key}` | Add a key |
| DELETE | /admin/keys/{provider}/{id} | Revoke a key |
| POST | /admin/keys/{provider}/{id}/test | Live check of one key |
| POST | /admin/keys/{provider}/active `{id}` | Manual switch |
| POST | /admin/keys/auto `{enabled}` | Turn automatic failover on/off |

Providers: groq, tavily, newsdata, serp, openweather, fish.
Errors: 401 bad token, 400 bad user id, 503 no usable key / not configured, 502 provider failed.
Keys are loaded from the `*_API_KEYS` environment variables (comma separated) and from the admin endpoints. See `backend/.env.example`.

The app's Settings, API keys screen uses the admin endpoints above with the admin token. Key values are never returned, only ids and status.
