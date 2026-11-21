"""Applies the ALEX native layer on top of the freshly generated Android scaffold."""
import pathlib
import re
import sys

root = pathlib.Path("android/app/src/main")
ma = next(root.rglob("MainActivity.kt"), None)
if ma is None:
    sys.exit("ERROR: generated MainActivity.kt not found")
m = re.search(r"^package\s+([\w.]+)", ma.read_text(), re.M)
if not m:
    sys.exit("ERROR: no package line in generated MainActivity.kt")
pkg = m.group(1)

sources = sorted(pathlib.Path("android_overrides").glob("*.kt"))
if not sources:
    sys.exit("ERROR: no Kotlin files in android_overrides/")
for src in sources:
    (ma.parent / src.name).write_text(src.read_text().replace("__PACKAGE__", pkg))

mf = root / "AndroidManifest.xml"
text = mf.read_text()
perms = [
    "INTERNET", "RECORD_AUDIO", "MODIFY_AUDIO_SETTINGS", "CAMERA",
    "READ_CONTACTS", "POST_NOTIFICATIONS", "QUERY_ALL_PACKAGES",
]
add = "".join(
    f'    <uses-permission android:name="android.permission.{p}"/>\n'
    for p in perms
    if f"android.permission.{p}" not in text
)
for feat in ("camera", "camera.flash"):
    if f"android.hardware.{feat}" not in text:
        add += f'    <uses-feature android:name="android.hardware.{feat}" android:required="false"/>\n'
if "<application" not in text:
    sys.exit("ERROR: <application> not found in manifest")
text = text.replace("<application", add + "    <application", 1)
text = re.sub(r'android:label="[^"]*"', 'android:label="ALEX AI"', text, count=1)
mf.write_text(text)
print(f"Patched package={pkg}; kotlin files={[s.name for s in sources]}; permissions={perms}")
