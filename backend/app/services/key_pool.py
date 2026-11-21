"""Pool of API keys per provider with automatic failover and manual switching.

Key values never leave this module except to be used for an outgoing request:
listings expose only ids, status and counters.
"""
import hashlib
import json
import logging
import os
import time
import uuid

log = logging.getLogger("alex.keys")


class QuotaError(Exception):
    """The key was rejected or is out of quota. Raised by provider calls."""

    def __init__(self, cooldown: int = 3600, permanent: bool = False):
        super().__init__("key rejected or exhausted")
        self.cooldown = cooldown
        self.permanent = permanent


class KeyUnavailable(Exception):
    """No usable key is left for the provider."""


def _fp(key: str) -> str:
    return hashlib.sha256(key.encode()).hexdigest()[:12]


class KeyPool:
    def __init__(self, path, providers, seed=None):
        self.path = path
        self.providers = tuple(providers)
        self.auto = True
        self.data = {p: {"active": None, "keys": []} for p in self.providers}
        self.stats = {p: {"calls": 0, "failures": 0} for p in self.providers}
        self._load()
        for provider, keys in (seed or {}).items():
            if provider not in self.data:
                continue
            known = {e["fp"] for e in self.data[provider]["keys"]}
            for key in keys:
                if _fp(key) not in known:  # revoked keys stay revoked after restart
                    self._append(provider, key)
        self._save()

    # ---- persistence -------------------------------------------------
    def _load(self):
        if not os.path.exists(self.path):
            return
        try:
            with open(self.path, encoding="utf-8") as fh:
                raw = json.load(fh)
        except (OSError, ValueError):
            log.error("Could not read key store; starting empty")
            return
        self.auto = bool(raw.get("auto", True))
        for p in self.providers:
            entry = raw.get("providers", {}).get(p)
            if isinstance(entry, dict):
                self.data[p] = {"active": entry.get("active"), "keys": entry.get("keys", [])}

    def _save(self):
        folder = os.path.dirname(self.path) or "."
        os.makedirs(folder, exist_ok=True)
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump({"auto": self.auto, "providers": self.data}, fh)
        try:
            os.chmod(tmp, 0o600)
        except OSError:
            pass
        os.replace(tmp, self.path)

    # ---- management --------------------------------------------------
    def _append(self, provider, key):
        entry = {"id": uuid.uuid4().hex[:8], "key": key, "fp": _fp(key), "status": "ok", "until": 0}
        d = self.data[provider]
        d["keys"].append(entry)
        if d["active"] is None:
            d["active"] = entry["id"]
        return entry["id"]

    def add(self, provider, key):
        key = key.strip()
        if provider not in self.data or not key:
            raise ValueError("bad provider or empty key")
        key_id = self._append(provider, key)
        self._save()
        return key_id

    def _get(self, provider, key_id):
        for e in self.data[provider]["keys"]:
            if e["id"] == key_id:
                return e
        return None

    def get_key(self, provider, key_id):
        e = self._get(provider, key_id)
        return e["key"] if e and e["status"] != "revoked" else None

    def revoke(self, provider, key_id):
        e = self._get(provider, key_id)
        if e is None:
            return False
        e["key"] = ""
        e["status"] = "revoked"
        d = self.data[provider]
        if d["active"] == key_id:
            nxt = next((x for x in d["keys"] if x["status"] == "ok"), None)
            d["active"] = nxt["id"] if nxt else None
        self._save()
        return True

    def set_active(self, provider, key_id):
        e = self._get(provider, key_id)
        if e is None or e["status"] == "revoked":
            return False
        self.data[provider]["active"] = key_id
        self._save()
        return True

    def set_auto(self, enabled):
        self.auto = bool(enabled)
        self._save()

    def mark(self, provider, key_id, ok):
        e = self._get(provider, key_id)
        if e is None or e["status"] == "revoked":
            return
        e["status"] = "ok" if ok else "invalid"
        e["until"] = 0
        self._save()

    def listing(self):
        out = {}
        for p in self.providers:
            d = self.data[p]
            out[p] = {
                "active": d["active"],
                "calls": self.stats[p]["calls"],
                "failures": self.stats[p]["failures"],
                "keys": [{"id": e["id"], "status": e["status"]} for e in d["keys"]],
            }
        return {"auto": self.auto, "providers": out}

    # ---- selection and calling --------------------------------------
    @staticmethod
    def _live(entry, now):
        if entry["status"] == "ok":
            return True
        if entry["status"] == "cooling" and now >= entry["until"]:
            entry["status"] = "ok"
            return True
        return False

    def _pick(self, provider, tried):
        now = time.time()
        d = self.data[provider]
        keys = d["keys"]
        if not self.auto:
            e = self._get(provider, d["active"])
            if e and e["id"] not in tried and self._live(e, now):
                return e
            return None
        start = next((i for i, e in enumerate(keys) if e["id"] == d["active"]), 0)
        for e in keys[start:] + keys[:start]:
            if e["id"] not in tried and self._live(e, now):
                d["active"] = e["id"]
                return e
        return None

    async def call(self, provider, fn):
        tried = set()
        while True:
            entry = self._pick(provider, tried)
            if entry is None:
                raise KeyUnavailable(f"No usable {provider} key")
            self.stats[provider]["calls"] += 1
            try:
                return await fn(entry["key"])
            except QuotaError as err:
                self.stats[provider]["failures"] += 1
                entry["status"] = "invalid" if err.permanent else "cooling"
                entry["until"] = time.time() + err.cooldown
                tried.add(entry["id"])
                self._save()
                log.warning("%s key %s marked %s", provider, entry["id"], entry["status"])
                if not self.auto:
                    raise KeyUnavailable(f"{provider} key {entry['id']} failed; switch manually")
