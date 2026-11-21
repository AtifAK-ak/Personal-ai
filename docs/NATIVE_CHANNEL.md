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

Unknown methods return `notImplemented`; exceptions become `NATIVE_ERROR`.
