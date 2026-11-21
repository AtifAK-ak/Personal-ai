import hmac
import re

from fastapi import HTTPException, Request

USER_ID_RE = re.compile(r"^[A-Za-z0-9_-]{8,64}$")


def _bearer(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.lower().startswith("bearer ") else ""


def _same(a: str, b: str) -> bool:
    return hmac.compare_digest(a.encode(), b.encode())


def require_user(request: Request) -> str:
    """App-level auth: shared app token plus an anonymous per-device user id."""
    expected = request.app.state.settings.app_token
    if not expected:
        raise HTTPException(503, "Server is not configured (ALEX_APP_TOKEN missing)")
    if not _same(_bearer(request), expected):
        raise HTTPException(401, "Invalid token")
    uid = request.headers.get("x-user-id", "")
    if not USER_ID_RE.match(uid):
        raise HTTPException(400, "Invalid X-User-Id")
    return uid


def require_admin(request: Request) -> None:
    expected = request.app.state.settings.admin_token
    if not expected:
        raise HTTPException(503, "Server is not configured (ALEX_ADMIN_TOKEN missing)")
    if not _same(_bearer(request), expected):
        raise HTTPException(401, "Invalid admin token")
