from conftest import ADMIN, AUTH

from app.routers import chat as chat_router


def test_health_is_public(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_auth_required(client):
    assert client.post("/chat", json={"message": "hi"}).status_code == 401
    bad = {"Authorization": "Bearer app-token", "X-User-Id": "x"}
    assert client.post("/chat", json={"message": "hi"}, headers=bad).status_code == 400


def test_chat_returns_validated_device_action(client, monkeypatch):
    async def fake_groq(pool, model, messages, json_mode=False, temperature=0.6):
        return ('{"intent":"device","reply":"Done","device":{"action":"flashlight","args":{"on":true}},'
                '"remember":["likes tea"]}')

    monkeypatch.setattr(chat_router.providers, "groq_chat", fake_groq)
    r = client.post("/chat", json={"message": "turn on my torch"}, headers=AUTH)
    assert r.status_code == 200
    assert r.json()["device_action"] == {"action": "flashlight", "args": {"on": True}}
    assert "likes tea" in client.get("/user/memory", headers=AUTH).json()["facts"]


def test_profile_and_validation(client):
    r = client.put("/user/profile", json={"persona_preset": "Close Friend"}, headers=AUTH)
    assert r.json()["persona_preset"] == "Close Friend"
    assert client.put("/user/profile", json={"persona_preset": "Nope"}, headers=AUTH).status_code == 400
    assert client.get("/user/profile", headers=AUTH).json()["owner"] == "Muhammad Atif"


def test_admin_keys_are_masked(client):
    assert client.get("/admin/keys").status_code == 401
    listing = client.get("/admin/keys", headers=ADMIN)
    assert listing.status_code == 200
    assert "gsk_test_key_one" not in listing.text
    assert len(listing.json()["providers"]["groq"]["keys"]) == 2
    assert client.post("/admin/keys/auto", json={"enabled": False}, headers=ADMIN).json() == {"auto": False}
