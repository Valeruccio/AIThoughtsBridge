#!/usr/bin/env python3
"""
Независимый парсер цитат с citaty.info.

Тянет все страницы пагинации для каждого URL из sources.txt
и пишет сухой текстовый файл: одна цитата — один блок, без метаданных.
"""

from __future__ import annotations

import argparse
import html as html_lib
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

USER_AGENT = (
    "Mozilla/5.0 (compatible; citaty-parser/1.0; +local research)"
)
REQUEST_DELAY_SEC = 0.6
MAX_PAGES_PER_SOURCE = 200

ARTICLE_RE = re.compile(
    r'<article[^>]*id="node-(\d+)"[^>]*class="[^"]*node-quote[^"]*"[^>]*>(.*?)</article>',
    re.S | re.I,
)
SPOILER_RE = re.compile(
    r'<div[^>]*id="spoiler-[^"]*"[^>]*>(.*?)</div>',
    re.S | re.I,
)
BODY_RE = re.compile(
    r'<div class="field-name-body">(.*?)</div>',
    re.S | re.I,
)


def fetch(url: str, retries: int = 3) -> str:
    last_err: Exception | None = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                url,
                headers={
                    "User-Agent": USER_AGENT,
                    "Accept": "text/html,application/xhtml+xml",
                    "Accept-Language": "ru,en;q=0.8",
                },
            )
            with urllib.request.urlopen(req, timeout=45) as resp:
                return resp.read().decode("utf-8", errors="replace")
        except (urllib.error.URLError, TimeoutError, OSError) as err:
            last_err = err
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Не удалось скачать {url}: {last_err}")


def clean_quote_html(raw: str) -> str:
    text = re.sub(r"<br\s*/?>", "\n", raw, flags=re.I)
    text = re.sub(r"</p\s*>", "\n", text, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)
    text = html_lib.unescape(text)
    text = text.replace("\xa0", " ").replace("\u200b", "")
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n[ \t]+", "\n", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_quotes(page_html: str) -> list[tuple[str, str]]:
    """Возвращает список (node_id, text)."""
    out: list[tuple[str, str]] = []
    for node_id, article in ARTICLE_RE.findall(page_html):
        spoiler = SPOILER_RE.search(article)
        body = BODY_RE.search(article)
        raw = spoiler.group(1) if spoiler else (body.group(1) if body else "")
        text = clean_quote_html(raw)
        if text:
            out.append((node_id, text))
    return out


def page_url(base: str, page: int) -> str:
    if page <= 0:
        return base
    sep = "&" if "?" in base else "?"
    return f"{base}{sep}page={page}"


def scrape_source(base_url: str, delay: float) -> list[tuple[str, str]]:
    collected: list[tuple[str, str]] = []
    seen_ids: set[str] = set()
    first_page_ids: set[str] | None = None

    for page in range(MAX_PAGES_PER_SOURCE):
        url = page_url(base_url, page)
        print(f"  [{page}] {url}", flush=True)
        html = fetch(url)
        quotes = extract_quotes(html)
        if not quotes:
            break

        page_ids = {qid for qid, _ in quotes}
        if first_page_ids is None:
            first_page_ids = page_ids
        elif page > 0 and page_ids == first_page_ids:
            # citaty.info зацикливает пагинацию на первую страницу
            break

        new_on_page = 0
        for qid, text in quotes:
            if qid in seen_ids:
                continue
            seen_ids.add(qid)
            collected.append((qid, text))
            new_on_page += 1

        if new_on_page == 0:
            break

        time.sleep(delay)

    return collected


def load_sources(path: Path) -> list[str]:
    urls: list[str] = []
    seen: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line in seen:
            continue
        seen.add(line)
        urls.append(line)
    return urls


def write_output(quotes: list[tuple[str, str]], out_path: Path) -> None:
    # Сухой файл: только текст цитат, блоки через пустую строку + ---
    blocks = [text for _, text in quotes]
    out_path.parent.mkdir(parents=True, exist_ok=True)
    body = "\n\n---\n\n".join(blocks)
    if body:
        body += "\n"
    out_path.write_text(body, encoding="utf-8")


def main() -> int:
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="Парсер цитат citaty.info")
    parser.add_argument(
        "--sources",
        type=Path,
        default=here / "sources.txt",
        help="Файл со списком URL",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=here / "output" / "quotes.txt",
        help="Выходной текстовый файл",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=REQUEST_DELAY_SEC,
        help="Пауза между запросами (сек)",
    )
    args = parser.parse_args()

    sources = load_sources(args.sources)
    if not sources:
        print("Нет URL в sources.txt", file=sys.stderr)
        return 1

    all_quotes: list[tuple[str, str]] = []
    global_seen: set[str] = set()

    for src in sources:
        print(f"\n=== {src} ===", flush=True)
        try:
            items = scrape_source(src, delay=args.delay)
        except Exception as err:
            print(f"ОШИБКА: {err}", file=sys.stderr)
            continue
        added = 0
        for qid, text in items:
            if qid in global_seen:
                continue
            global_seen.add(qid)
            all_quotes.append((qid, text))
            added += 1
        print(f"  -> {added} новых цитат (всего в источнике: {len(items)})", flush=True)

    write_output(all_quotes, args.out)
    print(f"\nГотово: {len(all_quotes)} цитат -> {args.out}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
