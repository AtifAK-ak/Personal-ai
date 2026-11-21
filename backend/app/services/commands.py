"""Whitelist of device actions the LLM may request. Anything else is dropped."""

VOLUME_ACTIONS = {"up", "down", "mute", "unmute", "set"}


def validate_device_action(raw):
    if not isinstance(raw, dict):
        return None
    action = raw.get("action")
    args = raw.get("args") if isinstance(raw.get("args"), dict) else {}
    if action == "flashlight":
        return {"action": "flashlight", "args": {"on": args.get("on") is True}}
    if action == "volume":
        sub = args.get("action")
        if sub not in VOLUME_ACTIONS:
            return None
        out = {"action": sub}
        if sub == "set":
            try:
                out["percent"] = max(0, min(100, int(args.get("percent"))))
            except (TypeError, ValueError):
                return None
        return {"action": "volume", "args": out}
    if action == "open_app":
        name = args.get("name")
        if isinstance(name, str) and 0 < len(name.strip()) <= 40:
            return {"action": "open_app", "args": {"name": name.strip()}}
    return None
