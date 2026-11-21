"""Per-user storage (profile, memory facts, recent history) as small JSON files.

Fine for a personal deployment. On hosts with ephemeral disks mount a persistent
volume at ALEX_DATA_DIR, or replace this class with a database.
"""
import json
import os
import re

USER_ID_RE = re.compile(r"^[A-Za-z0-9_-]{8,64}$")
MAX_FACTS = 100
MAX_HISTORY = 20

DEFAULT_PROFILE = {
    "name": "",
    "persona_preset": "Normal Assistant",
    "persona_custom": "",
    "voice": "aisha",
}


class UserStore:
    def __init__(self, root):
        self.root = root
        os.makedirs(root, exist_ok=True)

    def _path(self, uid):
        if not USER_ID_RE.match(uid):
            raise ValueError("invalid user id")
        return os.path.join(self.root, uid + ".json")

    def load(self, uid):
        data = {"profile": dict(DEFAULT_PROFILE), "memory": [], "history": []}
        try:
            with open(self._path(uid), encoding="utf-8") as fh:
                raw = json.load(fh)
            data["profile"].update(raw.get("profile", {}))
            data["memory"] = list(raw.get("memory", []))
            data["history"] = list(raw.get("history", []))
        except (OSError, ValueError):
            pass
        return data

    def save(self, uid, data):
        data["memory"] = data["memory"][-MAX_FACTS:]
        data["history"] = data["history"][-MAX_HISTORY:]
        path = self._path(uid)
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False)
        os.replace(tmp, path)
