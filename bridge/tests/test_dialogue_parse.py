# -*- coding: utf-8 -*-
from dialogue_parse import parse_dialogue_payload


def test_parse_json_ok():
    p = parse_dialogue_payload(
        '{"text":"Hold on","address_mode":"named","address_to":"Masha","should_end":false}'
    )
    assert p["text"] == "Hold on"
    assert p["address_mode"] == "named"
    assert p["address_to"] == "Masha"
    assert p["should_end"] is False


def test_parse_plain_fallback():
    p = parse_dialogue_payload("just a line")
    assert p["text"] == "just a line"
    assert p["address_mode"] == "all"


def test_parse_should_end_true():
    p = parse_dialogue_payload('{"text":"Enough.","address_mode":"all","address_to":"","should_end":true}')
    assert p["should_end"] is True
