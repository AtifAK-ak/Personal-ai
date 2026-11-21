import json
import os
from dataclasses import dataclass, field

PROVIDERS = ("groq", "tavily", "newsdata", "serp", "openweather", "fish")

ENV_KEYS = {
    "groq": "GROQ_API_KEYS",
    "tavily": "TAVILY_API_KEYS",
    "newsdata": "NEWSDATA_API_KEYS",
    "serp": "SERP_API_KEYS",
    "openweather": "OPENWEATHER_API_KEYS",
    "fish": "FISH_API_KEYS",
}


def _split(value):
    return [x.strip() for x in (value or "").split(",") if x.strip()]


@dataclass
class Settings:
    app_token: str = ""
    admin_token: str = ""
    data_dir: str = "./data"
    owner_name: str = "Muhammad Atif"
    groq_model: str = "llama-3.3-70b-versatile"
    groq_stt_model: str = "whisper-large-v3-turbo"
    fish_model: str = "s2.1-pro"
    voice_ids: dict = field(default_factory=dict)
    seed_keys: dict = field(default_factory=dict)


def load_settings() -> Settings:
    env = os.environ
    try:
        voice_ids = json.loads(env.get("FISH_VOICE_IDS") or "{}")
        if not isinstance(voice_ids, dict):
            voice_ids = {}
    except ValueError:
        voice_ids = {}
    return Settings(
        app_token=env.get("ALEX_APP_TOKEN", ""),
        admin_token=env.get("ALEX_ADMIN_TOKEN", ""),
        data_dir=env.get("ALEX_DATA_DIR", "./data"),
        owner_name=env.get("ALEX_OWNER_NAME", "Muhammad Atif"),
        groq_model=env.get("GROQ_MODEL", "llama-3.3-70b-versatile"),
        groq_stt_model=env.get("GROQ_STT_MODEL", "whisper-large-v3-turbo"),
        fish_model=env.get("FISH_MODEL", "s2.1-pro"),
        voice_ids=voice_ids,
        seed_keys={p: _split(env.get(var)) for p, var in ENV_KEYS.items()},
    )
