# AI Thoughts — Spoken Dialogues

**Build 42 only** — see [B42.md](B42.md) for install / bridge `.txt` paths.

Spoken AI dialogue between nearby player characters (Mode B host bridge). Separate from private inner thoughts.

## Channels

| Channel | Who sees it | Sound / zombies |
|---------|-------------|-----------------|
| **Thought** | Only the thinking player (private sticky, cool blue) | Never (unless Think Aloud) |
| **Dialogue (serious)** | Nearby + participants (warm subtitle) | Sandbox `DialogueAttractsZombies` |
| **Small talk (quiet)** | Nearby + participants (warm subtitle) | **Never** — subtitle only |

## Flow

1. Client detects a trigger near ≥1 other player → `DialogueEvent`.
2. Server opens one **session** per group; picks first speaker; queues LLM `kind=dialogue`.
3. Bridge returns JSON: `{ text, address_mode, address_to, should_end }`.
4. Server broadcasts `DialogueLine` in radius.
5. Serious: speaker may `Say` + `addSound` if zombies-on. Quiet: subtitle only.
6. Turn gap → next speaker. Ends on `should_end` / max turns / dispersal → group cooloff.

## Quiet small talk

Rare casual talk when calm (low panic/stress, no combat, no close zombies):

- Topics: joke, gripe, story, memory, dream, want, observe, ask, praise, roast
- Max **3** turns; group cooloff `SmallTalkMinutes` (default 10)
- **BANTER CARD**: optional nicknames from target traits + speaker tone (heat soft/normal/spicy)
  - e.g. Overweight → Жиртрест/Жируха; Underweight → Дрищ/Худышка; Illiterate → Тупорез; Strong → Красавчик/Молодец
- Nicknames are **never forced** every line; character first

Calm `player_nearby` without a small-talk roll stays an **inner thought** only.

## Address modes

- `void` — into empty air / self
- `all` — the group
- `named` — one person (gender-aware grammar in RU)

## Soft priority (never forced)

character/traits → relationship memory → trigger → banter tone → mood/state → gender grammar

## Serious triggers

`player_died_near`, `ally_hurt`, `illness_visible`, `shared_danger`, `friendly_fire`, `player_kill_player`, `reunion`, `plan_critical`, `aftershock_group`, `ammo_check_group`, `loot_dispute`, `moral_panic`

## Sandbox

- `DialogueEnabled` / `DialogueAttractsZombies` / `DialogueHearRadius`
- `SmallTalkEnabled` (default true)
- `BanterHeat` — Soft / Normal / Spicy
- `SmallTalkMinutes` — casual group cooloff

## Memory

Server `ModData` pairwise (`DST_13_Memory`). Roast −1 affinity, praise +1.

## Protocol

| Direction | Command | Notes |
|-----------|---------|-------|
| C→S | `DialogueEvent` | slim trigger + nearby |
| S→near | `DialogueLine` | + `quiet`, `attracts_zombies` |
| S→near | `DialogueEnded` | reason |
| S→one | `Thought` | private |

## How to test

1. Enable mod **AI Thoughts** in PZ (folder `DeepSeekThoughts/`).
2. Host: run Bridge Launcher or `python bridge/deepseek_bridge.py` with API key.
3. Sandbox: Dialogue + SmallTalk on; Attracts on (to verify quiet talk does **not** pull zombies).
4. Two players nearby, calm (house / car / loot), wait ~1–5 min for a quiet line.
5. Roast check: ShortTemper/Desensitized near Overweight + BanterHeat Normal/Spicy.
6. Praise check: warm affinity + Athletic/Strong target.
