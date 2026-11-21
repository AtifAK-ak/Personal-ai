import asyncio

import pytest

from app.services.key_pool import KeyPool, KeyUnavailable, QuotaError

PROVIDERS = ("groq", "tavily")


def make(tmp_path, keys=("aaaaaaaa1", "bbbbbbbb2", "cccccccc3")):
    return KeyPool(str(tmp_path / "keys.json"), PROVIDERS, {"groq": list(keys)})


def test_auto_failover_to_next_key(tmp_path):
    pool = make(tmp_path)
    used = []

    async def fn(key):
        used.append(key)
        if key == "aaaaaaaa1":
            raise QuotaError()
        return "ok"

    assert asyncio.run(pool.call("groq", fn)) == "ok"
    assert used == ["aaaaaaaa1", "bbbbbbbb2"]
    assert pool.listing()["providers"]["groq"]["keys"][0]["status"] == "cooling"


def test_manual_mode_does_not_switch(tmp_path):
    pool = make(tmp_path)
    pool.set_auto(False)

    async def fn(key):
        raise QuotaError()

    with pytest.raises(KeyUnavailable):
        asyncio.run(pool.call("groq", fn))


def test_all_keys_exhausted(tmp_path):
    pool = make(tmp_path)

    async def fn(key):
        raise QuotaError(permanent=True)

    with pytest.raises(KeyUnavailable):
        asyncio.run(pool.call("groq", fn))


def test_listing_never_contains_key_values(tmp_path):
    pool = make(tmp_path)
    assert "aaaaaaaa1" not in str(pool.listing())


def test_revoked_key_stays_revoked_after_restart(tmp_path):
    pool = make(tmp_path)
    key_id = pool.listing()["providers"]["groq"]["keys"][0]["id"]
    assert pool.revoke("groq", key_id)
    again = make(tmp_path)
    statuses = [k["status"] for k in again.listing()["providers"]["groq"]["keys"]]
    assert statuses.count("revoked") == 1 and len(statuses) == 3
