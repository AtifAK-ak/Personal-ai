"""Thin HTTP clients for the external services. Keys come from the KeyPool."""
import httpx

from .key_pool import QuotaError

TIMEOUT = httpx.Timeout(30.0)


class ProviderError(Exception):
    def __init__(self, status: int, detail: str = ""):
        super().__init__(f"provider error {status}")
        self.status = status
        self.detail = detail


def _check(resp: httpx.Response) -> None:
    if resp.status_code in (401, 403):
        raise QuotaError(permanent=True)
    if resp.status_code == 402:
        raise QuotaError(cooldown=6 * 3600)
    if resp.status_code == 429:
        raise QuotaError(cooldown=120)
    if resp.status_code >= 400:
        raise ProviderError(resp.status_code, resp.text[:200])


# ---- raw calls (one key) ------------------------------------------------
async def _groq_chat(key, model, messages, json_mode, temperature):
    body = {"model": model, "messages": messages, "temperature": temperature}
    if json_mode:
        body["response_format"] = {"type": "json_object"}
    async with httpx.AsyncClient(timeout=TIMEOUT) as c:
        r = await c.post(
            "https://api.groq.com/openai/v1/chat/completions",
            json=body,
            headers={"Authorization": f"Bearer {key}"},
        )
    _check(r)
    return r.json()["choices"][0]["message"]["content"]


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
async def groq_chat(pool, model, messages, json_mode=False, temperature=0.6):
    return await pool.call("groq", lambda k: _groq_chat(k, model, messages, json_mode, temperature))


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
