from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from ..core.security import require_user
from ..services.persona import PRESETS
from .voice import VOICE_IDS

router = APIRouter(prefix="/user")


class ProfileIn(BaseModel):
    name: str | None = Field(default=None, max_length=60)
    persona_preset: str | None = None
    persona_custom: str | None = Field(default=None, max_length=2000)
    voice: str | None = None


class FactIn(BaseModel):
    fact: str = Field(min_length=1, max_length=200)


@router.get("/profile")
async def get_profile(request: Request, uid: str = Depends(require_user)):
    s = request.app.state
    return {"owner": s.settings.owner_name, **s.store.load(uid)["profile"]}


@router.put("/profile")
async def put_profile(body: ProfileIn, request: Request, uid: str = Depends(require_user)):
    s = request.app.state
    data = s.store.load(uid)
    if body.persona_preset is not None and body.persona_preset not in PRESETS:
        raise HTTPException(400, "Unknown persona preset")
    if body.voice is not None and body.voice not in VOICE_IDS:
        raise HTTPException(400, "Unknown voice")
    for key, value in body.model_dump(exclude_none=True).items():
        data["profile"][key] = value
    s.store.save(uid, data)
    return data["profile"]


@router.get("/memory")
async def get_memory(request: Request, uid: str = Depends(require_user)):
    return {"facts": request.app.state.store.load(uid)["memory"]}


@router.post("/memory")
async def add_memory(body: FactIn, request: Request, uid: str = Depends(require_user)):
    s = request.app.state
    data = s.store.load(uid)
    if body.fact not in data["memory"]:
        data["memory"].append(body.fact)
    s.store.save(uid, data)
    return {"facts": data["memory"]}


@router.delete("/memory/{index}")
async def delete_fact(index: int, request: Request, uid: str = Depends(require_user)):
    s = request.app.state
    data = s.store.load(uid)
    if not 0 <= index < len(data["memory"]):
        raise HTTPException(404, "No such fact")
    data["memory"].pop(index)
    s.store.save(uid, data)
    return {"facts": data["memory"]}


@router.delete("/memory")
async def clear_memory(request: Request, uid: str = Depends(require_user)):
    s = request.app.state
    data = s.store.load(uid)
    data["memory"] = []
    s.store.save(uid, data)
    return {"facts": []}
