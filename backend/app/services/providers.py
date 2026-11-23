"""Thin HTTP clients for the external services. Keys come from the KeyPool."""
import json
import logging

import httpx

from .key_pool import QuotaError

log = logging.getLogger("alex.groq")

TIMEOUT = httpx.Timeout(30.0)


class ProviderError(Exception):
    def __init__(self, status: int, detail: str = ""):
        super().__init__(f"provider error {status}")
        self.status = status
        self.detail = detail


def _key_errors(resp) -> None:
    """Key problems: handled by key rotation, never by switching models."""
    if resp.status_code in (401, 403):
        raise QuotaError(permanent=True)
    if resp.status_code == 402:
        raise QuotaError(cooldown=6 * 3600)
    if resp.status_code == 429:
        raise QuotaError(cooldown=120)


def _check(resp) -> None:
    _key_errors(resp)
    if resp.status_code >= 400:
        raise ProviderError(resp.status_code, resp.text[:200])


# ---- raw calls (one key) ------------------------------------------------
# ---- Groq model policy -----------------------------------------------------
# Primary model, then one backup. Nothing else is ever chosen automatically.
GROQ_STATE = {"model": None, "json_ok": True}
GROQ_BASE = "https://api.groq.com/openai/v1"
_MODEL_WORDS = (
    "model_not_found", "model_decommissioned", "decommission", "deprecated",
    "no longer supported", "does not exist", "not found", "unsupported model",
    "is not supported", "not available",
)
_JSON_WORDS = ("response_format", "json_object", "json mode", "json_validate", "structured output")


def error_info(resp):
    """(code, message) from a Groq error response."""
    try:
        err = resp.json().get("error", {})
    except (ValueError, AttributeError):
        return "", str(getattr(resp, "text", ""))[:200]
    if not isinstance(err, dict):
        return "", str(err)[:200]
    return str(err.get("code") or ""), str(err.get("message") or "")[:300]


def classify_model_error(status, code, message):
    """'model' (not found / retired / unsupported), 'json' (JSON mode unsupported) or None.

    Only HTTP 400/404 can be a model problem. Anything else (401/403/429/5xx, or a 400
    that is not about the model) must NOT cause a model switch."""
    if status not in (400, 404):
        return None
    text = f"{code} {message}".lower()
    if any(w in text for w in _JSON_WORDS):
        return "json"
    if code.lower() in ("model_not_found", "model_decommissioned"):
        return "model"
    if "model" in text and any(w in text for w in _MODEL_WORDS):
        return "model"
    return None


def _headers(key):
    return {"Authorization": f"Bearer {key}"}


async def _groq_post(key, body):
    async with httpx.AsyncClient(timeout=TIMEOUT) as c:
        return await c.post(f"{GROQ_BASE}/chat/completions", json=body, headers=_headers(key))


async def _groq_available(key):
    """Set of model ids this key can use, or None when the list cannot be read."""
    async with httpx.AsyncClient(timeout=TIMEOUT) as c:
        r = await c.get(f"{GROQ_BASE}/models", headers=_headers(key))
    _key_errors(r)
    if r.status_code >= 400:
        return None
    return {m.get("id") for m in r.json().get("data", [])}


async def _groq_validate(key, model):
    """Real chat completion in JSON mode. Returns 'ok', 'model' or 'json'."""
    r = await _groq_post(key, {
        "model": model,
        "messages": [
            {"role": "system", "content": "Reply with a JSON object."},
            {"role": "user", "content": 'Return {"ok": true} as JSON.'},
        ],
        "temperature": 0,
        "response_format": {"type": "json_object"},
    })
    _key_errors(r)
    if r.status_code == 200:
        try:
            content = r.json()["choices"][0]["message"]["content"]
            return "ok" if isinstance(json.loads(content), dict) else "json"
        except (ValueError, KeyError, IndexError, TypeError):
            return "json"
    code, msg = error_info(r)
    kind = classify_model_error(r.status_code, code, msg)
    if kind:
        return kind
    raise ProviderError(r.status_code, msg)


async def _groq_select(key, models):
    available = await _groq_available(key)
    candidates = [m for m in models if available is None or m in available]
    if not candidates:
        raise ProviderError(0, "None of the configured Groq models (" + ", ".join(models) + ") is available for this key")
    json_fallback = None
    for m in candidates:
        result = await _groq_validate(key, m)
        log.info("groq model check %s -> %s", m, result)
        if result == "ok":
            GROQ_STATE.update(model=m, json_ok=True)
            return
        if result == "json" and json_fallback is None:
            json_fallback = m
    if json_fallback:
        log.warning("no Groq model passed the JSON-mode test; using %s without JSON mode", json_fallback)
        GROQ_STATE.update(model=json_fallback, json_ok=False)
        return
    raise ProviderError(0, "No configured Groq model passed the availability check")


async def _groq_chat(key, models, messages, json_mode, temperature):
    for attempt in range(2):
        if GROQ_STATE["model"] is None:
            await _groq_select(key, models)
        body = {"model": GROQ_STATE["model"], "messages": messages, "temperature": temperature}
        if json_mode and GROQ_STATE["json_ok"]:
            body["response_format"] = {"type": "json_object"}
        r = await _groq_post(key, body)
        _key_errors(r)
        if r.status_code in (400, 404) and attempt == 0:
            code, msg = error_info(r)
            kind = classify_model_error(r.status_code, code, msg)
            if kind:
                log.warning("groq model %s rejected (%s): %s", GROQ_STATE["model"], kind, msg)
                GROQ_STATE["model"] = None
                continue
        _check(r)
        return r.json()["choices"][0]["message"]["content"]
    raise ProviderError(0, "Groq model selection failed")


async def _groq_models(key):
    async with httpx.AsyncClient(timeout=TIMEOUT) as c:
        r = await c.get(
            "https://api.groq.com/openai/v1/models",
            headers={"Authorization": f"Bearer {key}"},
        )
    _check(r)
    return True


async def _groq_stt(key, model, filename, content, content_type, language):
    data = {"model": model}
    if language:
        data["language"] = language
    async with httpx.AsyncClient(timeout=httpx.Timeout(60.0)) as c:
        r = await c.post(
            "https://api.groq.com/openai/v1/audio/transcriptions",
            data=data,
            files={"file": (filename, content, content_type)},
            headers={"Authorization": f"Bearer {key}"},
        )
    _check(r)
    return r.json().get("text", "")


async def _tavily(key, query):
    async with httpx.AsyncClient(timeout=TIMEOUT) as c:
        r = await c.post(
            "https://api.tavily.com/search",
            json={"query": query, "max_results": 4, "include_answer": True},
            headers={"Authorization": f"Bearer {key}"},
        )
    _check(r)
    d = r.json()
    return {
        "answer": d.get("answer"),
        "results": [
            {"title": x.get("title"), "url": x.get("url"), "content": (x.get("content") or "")[:300]}
            for x in d.get("results", [])[:4]
        ],
    }


async def _newsdata(key, query, language):
    params = {"apikey": key, "language": language}
    if query:
        params["q"] = query
    async with httpx.AsyncClient(timeout=TIMEOUT) as c:
        r = await c.get("https://newsdata.io/api/1/latest", params=params)
    _check(r)
    return [
        {"title": x.get("title"), "source": x.get("source_id"), "link": x.get("link")}
        for x in r.json().get("results", [])[:5]
    ]


async def _serp(key, query):
    async with httpx.AsyncClient(timeout=TIMEOUT) as c:
        r = await c.get("https://serpapi.com/search.json", params={"q": query, "api_key": key})
    _check(r)
    return [
        {"title": x.get("title"), "url": x.get("link"), "content": (x.get("snippet") or "")[:300]}
        for x in r.json().get("organic_results", [])[:4]
    ]


async def _serp_account(key):
    async with httpx.AsyncClient(timeout=TIMEOUT) as c:
        r = await c.get("https://serpapi.com/account.json", params={"api_key": key})
    _check(r)
    return True


async def _weather(key, city):
    async with httpx.AsyncClient(timeout=TIMEOUT) as c:
        r = await c.get(
            "https://api.openweathermap.org/data/2.5/weather",
            params={"q": city, "appid": key, "units": "metric"},
        )
    if r.status_code == 404:
        raise ProviderError(404, "city not found")
    _check(r)
    d = r.json()
    return {
        "city": d.get("name"),
        "temp_c": d.get("main", {}).get("temp"),
        "feels_like_c": d.get("main", {}).get("feels_like"),
        "humidity": d.get("main", {}).get("humidity"),
        "wind_m_s": d.get("wind", {}).get("speed"),
        "description": (d.get("weather") or [{}])[0].get("description"),
    }


async def _fish_tts(key, model, text, reference_id):
    body = {"text": text, "format": "mp3"}
    if reference_id:
        body["reference_id"] = reference_id
    async with httpx.AsyncClient(timeout=httpx.Timeout(60.0)) as c:
        r = await c.post(
            "https://api.fish.audio/v1/tts",
            json=body,
            headers={"Authorization": f"Bearer {key}", "model": model},
        )
    _check(r)
    return r.content


# ---- pooled calls --------------------------------------------------------
async def groq_chat(pool, models, messages, json_mode=False, temperature=0.6):
    """models: (primary, backup). Key problems rotate keys; only model problems switch models."""
    return await pool.call("groq", lambda k: _groq_chat(k, tuple(models), messages, json_mode, temperature))


async def groq_transcribe(pool, model, filename, content, content_type, language=None):
    return await pool.call("groq", lambda k: _groq_stt(k, model, filename, content, content_type, language))


async def tavily_search(pool, query):
    return await pool.call("tavily", lambda k: _tavily(k, query))


async def serp_search(pool, query):
    return await pool.call("serp", lambda k: _serp(k, query))


async def newsdata_latest(pool, query, language="en"):
    return await pool.call("newsdata", lambda k: _newsdata(k, query, language))


async def openweather(pool, city):
    return await pool.call("openweather", lambda k: _weather(k, city))


async def fish_tts(pool, model, text, reference_id=None):
    return await pool.call("fish", lambda k: _fish_tts(k, model, text, reference_id))


async def probe(provider, key, fish_model="s2.1-pro"):
    """Cheap live check of one key. Returns True when the key works."""
    try:
        if provider == "groq":
            await _groq_models(key)
        elif provider == "tavily":
            await _tavily(key, "test")
        elif provider == "newsdata":
            await _newsdata(key, "test", "en")
        elif provider == "serp":
            await _serp_account(key)
        elif provider == "openweather":
            await _weather(key, "London")
        elif provider == "fish":
            await _fish_tts(key, fish_model, "Hi", None)
        else:
            return False
        return True
    except (QuotaError, ProviderError, httpx.HTTPError):
        return False
