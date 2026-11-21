import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from app.services.commands import validate_device_action  # noqa: E402
from app.services.persona import build_system_prompt  # noqa: E402


def test_whitelist_accepts_known_actions():
    assert validate_device_action({"action": "flashlight", "args": {"on": True}}) == {
        "action": "flashlight", "args": {"on": True}}
    out = validate_device_action({"action": "volume", "args": {"action": "set", "percent": 400}})
    assert out["args"]["percent"] == 100
    assert validate_device_action({"action": "open_app", "args": {"name": " YouTube "}})["args"]["name"] == "YouTube"


def test_whitelist_rejects_everything_else():
    assert validate_device_action({"action": "shell", "args": {"cmd": "rm -rf /"}}) is None
    assert validate_device_action({"action": "volume", "args": {"action": "explode"}}) is None
    assert validate_device_action("flashlight") is None


def test_system_prompt_has_owner_and_rules():
    p = build_system_prompt("Muhammad Atif", {"persona_preset": "Custom", "persona_custom": "Be brief"}, ["likes tea"])
    assert "Muhammad Atif" in p and "likes tea" in p and "Be brief" in p
    assert "never reveal secrets" in p
