from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from ..core.security import require_admin
from ..services import providers

router = APIRouter(prefix="/admin/keys", dependencies=[Depends(require_admin)])


class KeyIn(BaseModel):
    key: str = Field(min_length=8, max_length=300)


class ActiveIn(BaseModel):
    id: str


class AutoIn(BaseModel):
    enabled: bool


def _provider(request: Request, name: str):
    if name not in request.app.state.pool.providers:
        raise HTTPException(404, "Unknown provider")
    return request.app.state.pool


@router.get("")
async def list_keys(request: Request):
    """Ids, status and counters only. Key values are never returned."""
    return request.app.state.pool.listing()


@router.post("/auto")
async def set_auto(body: AutoIn, request: Request):
    request.app.state.pool.set_auto(body.enabled)
    return {"auto": body.enabled}


@router.post("/{provider}")
async def add_key(provider: str, body: KeyIn, request: Request):
    pool = _provider(request, provider)
    return {"id": pool.add(provider, body.key)}


@router.post("/{provider}/active")
async def set_active(provider: str, body: ActiveIn, request: Request):
    pool = _provider(request, provider)
    if not pool.set_active(provider, body.id):
        raise HTTPException(404, "No such key")
    return {"active": body.id}


@router.post("/{provider}/{key_id}/test")
async def test_key(provider: str, key_id: str, request: Request):
    pool = _provider(request, provider)
    key = pool.get_key(provider, key_id)
    if key is None:
        raise HTTPException(404, "No such key")
    ok = await providers.probe(provider, key, request.app.state.settings.fish_model)
    pool.mark(provider, key_id, ok)
    return {"id": key_id, "ok": ok}


@router.delete("/{provider}/{key_id}")
async def revoke_key(provider: str, key_id: str, request: Request):
    pool = _provider(request, provider)
    if not pool.revoke(provider, key_id):
        raise HTTPException(404, "No such key")
    return {"revoked": key_id}
