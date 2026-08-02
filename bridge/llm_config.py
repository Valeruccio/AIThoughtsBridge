# -*- coding: utf-8 -*-
"""Shared LLM provider config for bridge + launcher."""

from __future__ import annotations

import json
import os
from copy import deepcopy
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
CONFIG_PATH = ROOT / "bridge_config.json"
EXAMPLE_PATH = ROOT / "bridge_config.example.json"

DEFAULT_PROVIDERS: dict[str, dict[str, Any]] = {
    "deepseek": {
        "label": "DeepSeek API",
        "base_url": "https://api.deepseek.com",
        "model": "deepseek-chat",
        "api_key": "",
        "requires_key": True,
    },
    "ollama": {
        "label": "Ollama (local)",
        "base_url": "http://127.0.0.1:11434/v1",
        "model": "llama3.2",
        "api_key": "ollama",
        "requires_key": False,
    },
    "lmstudio": {
        "label": "LM Studio",
        "base_url": "http://127.0.0.1:1234/v1",
        "model": "local-model",
        "api_key": "lm-studio",
        "requires_key": False,
    },
    "openrouter": {
        "label": "OpenRouter",
        "base_url": "https://openrouter.ai/api/v1",
        "model": "deepseek/deepseek-chat",
        "api_key": "",
        "requires_key": True,
    },
    "custom": {
        "label": "Custom OpenAI-compatible",
        "base_url": "http://127.0.0.1:8080/v1",
        "model": "model-name",
        "api_key": "",
        "requires_key": False,
    },
}

PROVIDER_ORDER = ["deepseek", "ollama", "lmstudio", "openrouter", "custom"]


def default_config() -> dict[str, Any]:
    return {
        "active_provider": "deepseek",
        "providers": deepcopy(DEFAULT_PROVIDERS),
    }


def _merge_providers(raw: dict[str, Any] | None) -> dict[str, dict[str, Any]]:
    out = deepcopy(DEFAULT_PROVIDERS)
    if not isinstance(raw, dict):
        return out
    for pid, pdata in raw.items():
        if not isinstance(pdata, dict):
            continue
        base = out.get(pid, {
            "label": str(pid),
            "base_url": "",
            "model": "",
            "api_key": "",
            "requires_key": False,
        })
        merged = dict(base)
        for k in ("label", "base_url", "model", "api_key"):
            if k in pdata and pdata[k] is not None:
                merged[k] = str(pdata[k]).strip()
        if "requires_key" in pdata:
            merged["requires_key"] = bool(pdata["requires_key"])
        out[pid] = merged
    return out


def load_bridge_config() -> dict[str, Any]:
    """Load bridge_config.json; fall back to example then built-in defaults."""
    cfg = default_config()
    path = CONFIG_PATH if CONFIG_PATH.exists() else EXAMPLE_PATH
    if not path.exists():
        return cfg
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return cfg
    if not isinstance(raw, dict):
        return cfg
    active = str(raw.get("active_provider") or "deepseek").strip().lower()
    providers = _merge_providers(raw.get("providers"))
    if active not in providers:
        active = "deepseek" if "deepseek" in providers else next(iter(providers))
    return {"active_provider": active, "providers": providers}


def save_bridge_config(cfg: dict[str, Any]) -> None:
    active = str(cfg.get("active_provider") or "deepseek").strip().lower()
    providers = _merge_providers(cfg.get("providers"))
    if active not in providers:
        active = next(iter(providers))
    payload = {"active_provider": active, "providers": providers}
    CONFIG_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def is_local_url(base_url: str) -> bool:
    u = (base_url or "").lower()
    return any(
        h in u
        for h in (
            "127.0.0.1",
            "localhost",
            "0.0.0.0",
            "[::1]",
        )
    )


def placeholder_key(key: str) -> bool:
    k = (key or "").strip()
    return (not k) or k.startswith("sk-your-key")


def resolve_llm(
    *,
    env_api_key: str = "",
    env_model: str = "",
    env_base_url: str = "",
    game_api_key: str = "",
) -> dict[str, Any]:
    """
    Resolve active LLM endpoint.
    Priority: bridge_config.json → F9 settings key (if requires_key) → .env legacy.
    """
    cfg = load_bridge_config()
    pid = cfg["active_provider"]
    p = dict(cfg["providers"].get(pid) or DEFAULT_PROVIDERS["deepseek"])

    base_url = (p.get("base_url") or "").strip() or (env_base_url or "").strip() or "https://api.deepseek.com"
    model = (p.get("model") or "").strip() or (env_model or "").strip() or "deepseek-chat"
    requires_key = bool(p.get("requires_key"))
    api_key = (p.get("api_key") or "").strip()

    if placeholder_key(api_key):
        gk = (game_api_key or "").strip()
        if gk and not placeholder_key(gk):
            api_key = gk
        elif (env_api_key or "").strip() and not placeholder_key(env_api_key):
            api_key = (env_api_key or "").strip()

    if not api_key:
        # OpenAI client wants some string; locals accept dummy
        api_key = "local" if not requires_key else ""

    timeout = 120.0 if is_local_url(base_url) else 60.0

    return {
        "provider": pid,
        "label": p.get("label") or pid,
        "base_url": base_url.rstrip("/"),
        "model": model,
        "api_key": api_key,
        "requires_key": requires_key,
        "timeout": timeout,
        "config_path": str(CONFIG_PATH),
    }


def env_legacy_defaults() -> tuple[str, str, str]:
    return (
        os.getenv("DEEPSEEK_API_KEY", "").strip(),
        os.getenv("DEEPSEEK_MODEL", "deepseek-chat").strip(),
        os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com").strip(),
    )
