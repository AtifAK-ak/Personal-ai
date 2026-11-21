import logging
import os

from fastapi import FastAPI

from .core.config import PROVIDERS, Settings, load_settings
from .routers import admin, chat, user, voice
from .services.key_pool import KeyPool
from .services.store import UserStore

logging.basicConfig(level=logging.INFO)


def create_app(settings: Settings | None = None) -> FastAPI:
    """Run with: uvicorn app.main:create_app --factory"""
    settings = settings or load_settings()
    app = FastAPI(title="ALEX AI Backend", version="0.1.0")
    app.state.settings = settings
    app.state.pool = KeyPool(
        os.path.join(settings.data_dir, "keys.json"), PROVIDERS, settings.seed_keys
    )
    app.state.store = UserStore(os.path.join(settings.data_dir, "users"))

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    for r in (chat, voice, user, admin):
        app.include_router(r.router)
    return app
