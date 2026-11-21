import httpx
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, Response, UploadFile
from pydantic import BaseModel, Field

from ..core.security import require_user
from ..services import providers
from ..services.key_pool import KeyUnavailable

router = APIRouter()

VOICES = [
    {"id": "aisha", "name": "Aisha", "gender": "female", "trait": "Friendly", "language": "Hindi"},
    {"id": "sara", "name": "Sara", "gender": "female", "trait": "Professional", "language": "Hindi"},
    {"id": "zara", "name": "Zara", "gender": "female", "trait": "Calm", "language": "Hindi"},
    {"id": "noor", "name": "Noor", "gender": "female", "trait": "Elegant", "language": "English"},
    {"id": "ali", "name": "Ali", "gender": "male", "trait": "Professional", "language": "Hindi"},
    {"id": "ahmed", "name": "Ahmed", "gender": "male", "trait": "Cool", "language": "Hindi"},
    {"id": "hassan", "name": "Hassan", "gender": "male", "trait": "Deep", "language": "English"},
]
VOICE_IDS = {v["id"] for v in VOICES}
MAX_AUDIO_BYTES = 10 * 1024 * 1024


class TtsIn(BaseModel):
    text: str = Field(min_length=1, max_length=600)
    voice: str | None = None


@router.get("/voices")
async def voices(request: Request, uid: str = Depends(require_user)):
    configured = request.app.state.settings.voice_ids
    return {"voices": [{**v, "configured": bool(configured.get(v["id"]))} for v in VOICES]}


@router.post("/tts")
async def tts(body: TtsIn, request: Request, uid: str = Depends(require_user)):
    st = request.app.state
    voice = body.voice or st.store.load(uid)["profile"].get("voice", "aisha")
    if voice not in VOICE_IDS:
        raise HTTPException(400, "Unknown voice")
    reference_id = st.settings.voice_ids.get(voice) or None
    try:
        audio = await providers.fish_tts(st.pool, st.settings.fish_model, body.text, reference_id)
    except KeyUnavailable as e:
        raise HTTPException(503, str(e))
    except (providers.ProviderError, httpx.HTTPError):
        raise HTTPException(502, "The voice service did not answer")
    return Response(content=audio, media_type="audio/mpeg")


@router.post("/stt")
async def stt(request: Request, file: UploadFile = File(...), language: str | None = Form(None),
              uid: str = Depends(require_user)):
    st = request.app.state
    content = await file.read(MAX_AUDIO_BYTES + 1)
    if len(content) > MAX_AUDIO_BYTES:
        raise HTTPException(413, "Audio too large")
    try:
        text = await providers.groq_transcribe(
            st.pool, st.settings.groq_stt_model, file.filename or "audio.m4a",
            content, file.content_type or "application/octet-stream", language)
    except KeyUnavailable as e:
        raise HTTPException(503, str(e))
    except (providers.ProviderError, httpx.HTTPError):
        raise HTTPException(502, "The speech service did not answer")
    return {"text": text}
