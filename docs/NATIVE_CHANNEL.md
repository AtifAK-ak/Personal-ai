# Kotlin channel `alex/native`

| Method | Arguments | Returns | Permission |
|---|---|---|---|
| ping | none | status string | none |
| flashlight | on: bool | new state; error NO_FLASHLIGHT | none |
| volume | action: up/down/mute/unmute/set, percent | media volume % | none (media stream only) |
| app.open | name | opened app label; error APP_NOT_FOUND | QUERY_ALL_PACKAGES |
| prefs.get / prefs.set | key, value | string / true | none |
| permission.status / permission.request | name: microphone/camera/contacts/notifications | bool | the requested one |
| permission.openSettings | none | true | none |
| speech.listen / speech.stop | locale (ur-PK, en-US, hi-IN) | recognized text; errors NO_STT, NO_PERMISSION, STT_ERROR | RECORD_AUDIO |
| tts.speak | text, lang | true (phone's own voice) | none |
| audio.play / audio.stop | bytes (MP3) / none | true | none |
| device.battery | none | {percent, charging} | none |
| device.panel | name: wifi/bluetooth/mobile/display/sound | true | none |
| media.key | action: play/pause/next/previous/stop | true | none |
| camera.open | none | true (opens the camera app) | none |
| maps.open | query, navigate | true | none |
| web.search | query | true | none |
| contacts.search | query | list of {name, number} | READ_CONTACTS |
| contacts.dial | number | true (opens dialer, user presses call) | none |
| record.start / pause / resume / stop | none | file path (start, stop) | RECORD_AUDIO |

Unknown methods return `notImplemented`; exceptions become `NATIVE_ERROR`.
