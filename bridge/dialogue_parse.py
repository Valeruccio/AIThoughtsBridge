# -*- coding: utf-8 -*-
"""Dialogue JSON payload parser (no LLM deps)."""

from __future__ import annotations

import json
import re


def parse_dialogue_payload(raw: str) -> dict:
    """Extract dialogue JSON from model output."""
    text = (raw or "").strip()
    if not text:
        return {"text": "", "address_mode": "all", "address_to": "", "should_end": False}
    if text.startswith("```"):
        text = text.strip("`")
        if text.lower().startswith("json"):
            text = text[4:].strip()
    start = text.find("{")
    end = text.rfind("}")
    blob = text
    if start >= 0 and end > start:
        blob = text[start : end + 1]
    try:
        obj = json.loads(blob)
        if isinstance(obj, dict):
            mode = str(obj.get("address_mode") or "all").lower()
            if mode not in ("void", "all", "named"):
                mode = "all"
            line = str(obj.get("text") or obj.get("thought") or "").strip()
            return {
                "text": line,
                "address_mode": mode,
                "address_to": str(obj.get("address_to") or "").strip(),
                "should_end": bool(obj.get("should_end")),
            }
    except (json.JSONDecodeError, TypeError):
        pass
    line = text.replace("\n", " ").strip()
    if line.startswith("{") and "text" in line:
        m = re.search(r'"text"\s*:\s*"((?:\\.|[^"\\])*)"', line)
        if m:
            line = m.group(1)
    return {
        "text": line[:220],
        "address_mode": "all",
        "address_to": "",
        "should_end": False,
    }
