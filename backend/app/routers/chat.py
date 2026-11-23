import json
import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from ..core.security import require_user
from ..services import providers
from ..services.commands import validate_device_action
from ..services.key_pool import KeyUnavailable
from ..services.persona import build_system_prompt

log = logging.getLogger("alex.chat")
router = APIRouter()


class ChatIn(BaseModel):
    message: str = Field(min_length=1, max_length=2000)


def parse_llm_json(text: str) -> dict:
    try:
        data = json.loads(text)
    except ValueError:
        start, end = text.find("{"), text.rfind("}")
        data = None
        if start != -1 and end > start:
            try:
                data = json.loads(text[start : end + 1])
            except ValueError:
                data = None
    if not isinstance(data, dict):
        return {"intent": "chat", "reply": text.strip()}
    return data


async def _gather(pool, intent, plan):
    if intent == "weather":
        city = str(plan.get("city") or "").strip()[:60]
        return {"weather": await providers.openweather(pool, city)} if city else None
    query = str(plan.get("query") or "").strip()[:200]
    if not query and intent == "search":
        return None
    if intent == "news":
        lang = plan.get("language") if plan.get("language") in ("en", "ur", "hi") else "en"
        return {"news": await providers.newsdata_latest(pool, query, lang)}
    if intent == "search":
        try:
            return {"search": await providers.tavily_search(pool, query)}
        except KeyUnavailable:
            return {"search": await providers.serp_search(pool, query)}
    return None


@router.post("/chat")
async def chat(body: ChatIn, request: Request, uid: str = Depends(require_user)):
    st = request.app.state
    s = st.settings
    data = st.store.load(uid)
    history = data["history"][-10:]

    system = build_system_prompt(s.owner_name, data["profile"], data["memory"])
    messages = [{"role": "system", "content": system}, *history,
                {"role": "user", "content": body.message}]
    try:
        raw = await providers.groq_chat(st.pool, (s.groq_model, s.groq_backup_model), messages, json_mode=True)
    except KeyUnavailable as e:
        raise HTTPException(503, str(e))
    except providers.ProviderError as e:
        log.warning("groq error %s: %s", e.status, e.detail)
        raise HTTPException(502, f"AI service error ({e.status}): {e.detail}"[:300])
    except httpx.HTTPError:
        raise HTTPException(502, "The AI service did not answer")

    plan = parse_llm_json(raw)
    intent = plan.get("intent") if plan.get("intent") in ("chat", "weather", "news", "search", "device") else "chat"
    reply = str(plan.get("reply") or "").strip()
    device_action = validate_device_action(plan.get("device")) if intent == "device" else None

    if intent in ("weather", "news", "search"):
        try:
            found = await _gather(st.pool, intent, plan)
        except (KeyUnavailable, providers.ProviderError, httpx.HTTPError):
            found = None
            reply = "I could not fetch that information right now."
        if found:
            plain = build_system_prompt(s.owner_name, data["profile"], data["memory"], plain=True)
            follow = [
                {"role": "system", "content": plain},
                {"role": "user", "content": f"{body.message}\n\nUse only this data to answer briefly:\n{json.dumps(found, ensure_ascii=False)}"},
            ]
            try:
                reply = (await providers.groq_chat(st.pool, (s.groq_model, s.groq_backup_model), follow)).strip() or reply
            except (KeyUnavailable, providers.ProviderError, httpx.HTTPError):
                pass

    facts = plan.get("remember")
    if isinstance(facts, list):
        for f in facts[:3]:
            f = str(f).strip()[:200]
            if f and f not in data["memory"]:
                data["memory"].append(f)

    data["history"].append({"role": "user", "content": body.message})
    data["history"].append({"role": "assistant", "content": reply})
    st.store.save(uid, data)
    return {"reply": reply, "intent": intent, "device_action": device_action}
