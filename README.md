# AI Thoughts (Project Zomboid Build 42)

Мод, в котором персонаж говорит короткие **внутренние мысли** через LLM (DeepSeek API, Ollama, LM Studio, OpenRouter или любой OpenAI-compatible endpoint).

> В Lua у Zomboid нет свободного HTTP. Мод пишет JSON в файлы, локальный Python-мост дергает модель и возвращает ответ.

## Что уже сделано

| Часть | Описание |
|--------|----------|
| `DeepSeekThoughts/` | Мод B41 (Lua): снимок состояния, триггеры, `player:Say` |
| `bridge/` | Python-мост + **Bridge Launcher** (GUI) |
| Провайдеры | DeepSeek / Ollama / LM Studio / OpenRouter / Custom |
| Язык | F9: `ru` / `en` |
| Триггеры | паника/стресс, зомби, бой, погода, машина, ТВ/радио, … |

## Установка за 3 шага

### 1) Зависимости Python

```powershell
cd d:\zomboid_mods
.\.venv\Scripts\python.exe -m pip install -r .\bridge\requirements.txt
```

### 2) Поставить мод в игру

**Источник правды — git.** После `git clone` / `git pull` на **каждом** компе (хост и клиенты):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_mod.ps1
```

Скрипт зеркалит `DeepSeekThoughts/` → `%USERPROFILE%\Zomboid\mods\DeepSeekThoughts` (полная замена).  
Иначе MP ругается `File doesn't match the one on the server` (часто из‑за разных копий / CRLF).

В главном меню PZ: **Mods** → включить **AI Thoughts**.

### 3) Запустить Bridge Launcher

Двойной клик или:

```powershell
.\scripts\Start_DST_Bridge.bat
```

В окне:

1. Выбери **Provider** (DeepSeek / Ollama / LM Studio / OpenRouter / Custom)
2. При необходимости вставь **API key**, выбери **Model** (кнопка Refresh models)
3. **Save** → **Test connection** → **Start Bridge**
4. Играй — мост должен оставаться запущенным

Конфиг пишется в `bridge/bridge_config.json` (не коммитится; шаблон — `bridge_config.example.json`).

## Провайдеры

| Provider | Base URL (обычно) | Key |
|----------|-------------------|-----|
| DeepSeek | `https://api.deepseek.com` | нужен |
| Ollama | `http://127.0.0.1:11434/v1` | не нужен (`ollama pull llama3.2`) |
| LM Studio | `http://127.0.0.1:1234/v1` | не нужен (Local Server On) |
| OpenRouter | `https://openrouter.ai/api/v1` | нужен |
| Custom | свой `…/v1` | по желанию |

Смена провайдера: Save в лаунчере. Bridge перечитывает конфиг на **каждый** запрос мысли; если что-то странно — Stop → Start.

Legacy: `bridge/.env` с `DEEPSEEK_API_KEY` всё ещё работает как запасной вариант для DeepSeek.

## Настройки в игре

**F9** — язык, мат, тайминги. API key в F9 опционален, если всё настроено в Bridge Launcher / локальной модели.

Файл: `%USERPROFILE%\Zomboid\Lua\DeepSeekThoughts\settings.txt`

## Как это работает

```
Игра (Lua) --request.json--> Zomboid/Lua/DeepSeekThoughts/outbox/
Python bridge --LLM API-->
Игра читает <--response.json-- Zomboid/Lua/DeepSeekThoughts/inbox/
Персонаж: Say("…")
```

## Важно

- Ключи API только в `bridge/bridge_config.json` или `.env` **на машине хоста/сервера**.
- **Мультиплеер Mode B**: хост платит за API; bridge крутится у хоста; **всем игрокам показывается одна и та же мысль** (с именем персонажа). См. [docs/MP_DESIGN.md](docs/MP_DESIGN.md).
- Клиентам в MP Python-bridge не нужен — только хосту/dedicated.
- Solo: локальный bridge как раньше.
- Нет мыслей: F9 → Bridge status (у хоста); лаунчер пишет ли `thought:`.

## Дальше (можно добавить)

- Sandbox-флаг «только initiator видит» (отключить broadcast)
- Mode A (client-local) как опция
- Build 42 port
