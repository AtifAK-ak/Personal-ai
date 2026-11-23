import asyncio

import pytest

from app.services import providers
from app.services.key_pool import QuotaError

MODELS = ("openai/gpt-oss-120b", "openai/gpt-oss-20b")


class Resp:
    def __init__(self, status, body=None):
        self.status_code = status
        self._body = body or {}
        self.text = str(body)

    def json(self):
        return self._body


def ok(content):
    return Resp(200, {"choices": [{"message": {"content": content}}]})


def err(status, code, message):
    return Resp(status, {"error": {"code": code, "message": message}})


@pytest.fixture(autouse=True)
def reset_state():
    providers.GROQ_STATE.update(model=None, json_ok=True)
    yield


def install(monkeypatch, script, available=None):
    """script: model -> list of responses, consumed in order. Returns the call log."""
    calls = []

    async def fake_post(key, body):
        calls.append((body["model"], "response_format" in body))
        return script[body["model"]].pop(0)

    async def fake_available(key):
        return available

    monkeypatch.setattr(providers, "_groq_post", fake_post)
    monkeypatch.setattr(providers, "_groq_available", fake_available)
    return calls


def run(models=MODELS, json_mode=True):
    return asyncio.run(providers._groq_chat("k", models, [{"role": "user", "content": "hi"}], json_mode, 0.6))


def test_defaults_are_the_two_gpt_oss_models():
    from app.core.config import Settings

    s = Settings()
    assert (s.groq_model, s.groq_backup_model) == MODELS


def test_primary_is_used_when_it_works(monkeypatch):
    calls = install(monkeypatch, {MODELS[0]: [ok('{"ok": true}'), ok("hello")]})
    assert run() == "hello"
    assert [c[0] for c in calls] == [MODELS[0], MODELS[0]]
    assert providers.GROQ_STATE["model"] == MODELS[0]


def test_retired_primary_falls_back_to_backup_only(monkeypatch):
    calls = install(monkeypatch, {
        MODELS[0]: [err(400, "model_decommissioned", "The model `x` has been decommissioned")],
        MODELS[1]: [ok('{"ok": true}'), ok("from backup")],
    })
    assert run() == "from backup"
    assert {c[0] for c in calls} == set(MODELS)
    assert providers.GROQ_STATE["model"] == MODELS[1]


def test_unrelated_400_does_not_switch_model(monkeypatch):
    calls = install(monkeypatch, {MODELS[0]: [err(400, "invalid_request_error", "messages must not be empty")]})
    with pytest.raises(providers.ProviderError):
        run()
    assert [c[0] for c in calls] == [MODELS[0]]


def test_401_and_403_are_key_problems_not_model_problems(monkeypatch):
    for status in (401, 403):
        providers.GROQ_STATE.update(model=None, json_ok=True)
        calls = install(monkeypatch, {MODELS[0]: [err(status, "invalid_api_key", "Invalid API Key")]})
        with pytest.raises(QuotaError) as e:
            run()
        assert e.value.permanent
        assert [c[0] for c in calls] == [MODELS[0]]


def test_429_rotates_key_without_switching_model(monkeypatch):
    calls = install(monkeypatch, {MODELS[0]: [err(429, "rate_limit_exceeded", "Rate limit reached")]})
    with pytest.raises(QuotaError) as e:
        run()
    assert not e.value.permanent and e.value.cooldown == 120
    assert [c[0] for c in calls] == [MODELS[0]]


def test_api_list_order_is_not_used_and_unlisted_primary_is_skipped(monkeypatch):
    calls = install(
        monkeypatch,
        {MODELS[1]: [ok('{"ok": true}'), ok("hi")]},
        available={"llama-3.3-70b-versatile", MODELS[1]},
    )
    assert run() == "hi"
    assert {c[0] for c in calls} == {MODELS[1]}


def test_no_configured_model_available_is_an_error(monkeypatch):
    install(monkeypatch, {}, available={"llama-3.3-70b-versatile", "gemma2-9b-it"})
    with pytest.raises(providers.ProviderError):
        run()


def test_json_unsupported_everywhere_degrades_to_plain_mode(monkeypatch):
    calls = install(monkeypatch, {
        MODELS[0]: [err(400, "invalid_request_error", "response_format json_object is not supported"), ok("plain")],
        MODELS[1]: [err(400, "invalid_request_error", "response_format json_object is not supported")],
    })
    assert run() == "plain"
    assert providers.GROQ_STATE["json_ok"] is False
    assert calls[-1] == (MODELS[0], False)


def test_model_retired_after_selection_reselects_once(monkeypatch):
    install(monkeypatch, {
        MODELS[0]: [ok('{"ok": true}'), err(404, "model_not_found", "The model does not exist"),
                    err(404, "model_not_found", "The model does not exist")],
        MODELS[1]: [ok('{"ok": true}'), ok("recovered")],
    })
    assert run() == "recovered"
    assert providers.GROQ_STATE["model"] == MODELS[1]


def test_classifier():
    c = providers.classify_model_error
    assert c(404, "model_not_found", "x") == "model"
    assert c(400, "", "The model `a` does not exist or you do not have access") == "model"
    assert c(400, "", "response_format is not supported by this model") == "json"
    assert c(400, "invalid_request_error", "messages is required") is None
    for status in (401, 403, 429, 500, 503):
        assert c(status, "model_not_found", "model does not exist") is None
