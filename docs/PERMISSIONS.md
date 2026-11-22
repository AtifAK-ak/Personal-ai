# Permissions

Declared in the manifest by `tool/patch_android.py`; runtime permissions are requested only when the user taps Allow.

| Permission | Used for | Status |
|---|---|---|
| INTERNET | talking to the backend | in use |
| MODIFY_AUDIO_SETTINGS | volume | in use |
| QUERY_ALL_PACKAGES | finding installed apps by name | in use (fine for a sideloaded APK; Google Play restricts it) |
| RECORD_AUDIO | voice input (speech to text), audio recording | in use |
| CAMERA | declared for later in-app photos; "open camera" uses the camera app and needs no permission | declared |
| READ_CONTACTS | contact search | in use |
| POST_NOTIFICATIONS | status alerts | declared, feature not built yet |

Not available to normal apps: silent screenshots and always-on wake word (need MediaProjection/Accessibility and a foreground service).

Recording works while the app is open (no hidden background recording). Calls only open the dialer; the user presses call.
