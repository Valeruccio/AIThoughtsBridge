# Changelog — AI Thoughts

## 2026-08-01 — Build 42 migration (2.0.0)

- Versioned mod layout: `DeepSeekThoughts/42/` + `common/` (`versionMin=42.13.0`)
- Bridge IO: `request.txt` / `response.txt` / `status.txt` (JSON body); Python fallback to `.json`
- `DST_15_B42Compat`: CharacterStat / traits / world sound / SandboxVars
- Sandbox translations → `Sandbox.json` (EN/RU)
- Docs: [docs/B42.md](docs/B42.md)

## 2026-08-01 — Quiet small talk + banter

- `DST_14_Banter`: topic pool (joke/gripe/story/memory/dream/want/ask/praise/roast) + RU/EN nicknames
- Calm gates + rare roll; quiet sessions never Say/addSound (zombies ignored)
- Banter heat sandbox: Soft / Normal / Spicy; `SmallTalkEnabled`, `SmallTalkMinutes`
- BANTER CARD injected into dialogue LLM prompt; affinity deltas on roast/praise
- Docs: [docs/DIALOGUE.md](docs/DIALOGUE.md) test notes; mod **1.4.0**

## 2026-08-01 — Spoken dialogues (director layer)

- Separate channels: **private thoughts** vs **spoken dialogues** (Mode B)
- `DST_12_Dialogue` session director + turn queue; `DST_13_Memory` pairwise ModData
- Triggers: death, ally hurt, illness, shared danger, FF, PvP kill, reunion, aftershock, panic…
- Address modes: void / all / named (+ gender soft bias); warm dialogue HUD vs cool thought sticky
- Sandbox: `DialogueEnabled`, `DialogueAttractsZombies`, `DialogueHearRadius`
- Bridge `kind=dialogue` JSON replies (`text`, `address_mode`, `address_to`, `should_end`)
- Docs: [docs/DIALOGUE.md](docs/DIALOGUE.md), Mode B privacy updated in [docs/MP_DESIGN.md](docs/MP_DESIGN.md)

## 2026-08-01 — Human immersion trigger refactor

- Topic arcs (`DST_11_TopicArc`): media / inner / Mode B `open → build → dead_end → cooloff`
- Emotion phases: spike / aftershock / dwell / numb / wander (pacing + bridge length)
- Shorter WorldMain; hook micros less “director”; anti-machine filters v2 + tests
- New hooks: `topic_dead_end`, `drunk_wave`, `ammo_dry`, `eating`, `drinking`, `loot_find_rare`, `first_kill_session`, `player_nearby`
- Mode B host shared arc synced in broadcast (`arc_phase` / `arc_turns` / cooloff)

## 2026-08-01 — Mode B MP (host pays, shared display)

- Clients send slim `RequestThought`; host bridge; thoughts private to requester (updated)
- Flat shared IO on host; clients do not need Python in MP

## 2026-08-01 — SP quality pass

- Throttled poll, deferred combat, media cache, pacing module, API keys bridge-only
