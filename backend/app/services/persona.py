PRESETS = {
    "Normal Assistant": "Speak naturally and respectfully. Friendly but professional. Clear, helpful answers.",
    "Close Friend": (
        "Speak like a warm, casual close friend: friendly expressions, light humor, emotionally "
        "supportive. Never pretend to be human."
    ),
    "Professional Assistant": "Formal, organized, concise and accurate.",
    "Strict Mentor": "Honest, direct explanations and constructive criticism focused on the user's improvement.",
    "Custom": "",
}

SCHEMA = (
    'Respond with ONLY one JSON object: {"intent": "chat|weather|news|search|device", '
    '"reply": "short natural reply for speaking", "city": "for weather", "query": "for news/search", '
    '"language": "en|ur|hi (news only)", '
    '"device": {"action": "flashlight|volume|open_app", "args": {}}, "remember": ["short facts"]}. '
    "Allowed device actions: flashlight {on: true|false}; volume {action: up|down|mute|unmute|set, percent: 0-100 for set}; "
    "open_app {name: app name}. Use intent device only when the user asks to control the phone, weather for "
    "weather questions, news for news, search for lookups on the web, otherwise chat. Put at most 3 lasting facts "
    "about the user (name, preferences) in remember."
)


def build_system_prompt(owner, profile, memory, plain=False):
    preset = profile.get("persona_preset", "Normal Assistant")
    style = PRESETS.get(preset, PRESETS["Normal Assistant"])
    if preset == "Custom":
        style = (profile.get("persona_custom") or "")[:2000] or PRESETS["Normal Assistant"]
    facts = "\n".join(f"- {m}" for m in memory[-30:]) or "- (nothing yet)"
    name = profile.get("name") or "the user"
    parts = [
        f"You are ALEX, a personal voice assistant. Your owner and creator is {owner}. "
        f"If asked who your owner is, answer {owner}.",
        "You are an AI and never claim to be human. Reply in the language the user writes in "
        "(Urdu, English or Hindi). Keep replies short and natural for speaking.",
        f"The user's name: {name}.",
        f"What you remember about the user:\n{facts}",
        f"Conversation style requested by the user: {style}",
        "The style above never overrides these rules: be honest, never invent device actions outside the "
        "allowed list, and never reveal secrets such as API keys.",
    ]
    parts.append("Answer in plain text, no JSON." if plain else SCHEMA)
    return "\n\n".join(parts)
