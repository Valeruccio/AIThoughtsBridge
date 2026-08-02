#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AI Thoughts — Bridge Launcher (multi-provider GUI).

Run:
    .venv\\Scripts\\python.exe bridge\\launcher.py
    or scripts\\Start_DST_Bridge.bat
"""

from __future__ import annotations

import queue
import subprocess
import sys
import threading
import traceback
from pathlib import Path
from typing import Any

# Ensure bridge/ is on path when launched as script
ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

try:
    import tkinter as tk
    from tkinter import messagebox, ttk
except ImportError as e:
    print("tkinter is required for the launcher:", e)
    sys.exit(1)

from llm_config import (  # noqa: E402
    CONFIG_PATH,
    PROVIDER_ORDER,
    default_config,
    is_local_url,
    load_bridge_config,
    placeholder_key,
    save_bridge_config,
)

BRIDGE_SCRIPT = ROOT / "deepseek_bridge.py"


def _venv_python() -> Path:
    win = REPO / ".venv" / "Scripts" / "python.exe"
    unix = REPO / ".venv" / "bin" / "python"
    if win.exists():
        return win
    if unix.exists():
        return unix
    return Path(sys.executable)


def list_models(base_url: str, api_key: str) -> list[str]:
    from openai import OpenAI

    key = (api_key or "").strip() or "local"
    client = OpenAI(
        api_key=key,
        base_url=base_url.rstrip("/"),
        timeout=30.0,
    )
    resp = client.models.list()
    ids = []
    for m in getattr(resp, "data", None) or []:
        mid = getattr(m, "id", None)
        if mid:
            ids.append(str(mid))
    return sorted(set(ids))


def test_chat(base_url: str, api_key: str, model: str) -> str:
    from openai import OpenAI

    key = (api_key or "").strip() or "local"
    timeout = 120.0 if is_local_url(base_url) else 45.0
    client = OpenAI(api_key=key, base_url=base_url.rstrip("/"), timeout=timeout)
    resp = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": "Reply with exactly: ok"},
            {"role": "user", "content": "ping"},
        ],
        max_tokens=16,
        temperature=0,
    )
    text = (resp.choices[0].message.content or "").strip()
    return text or "(empty reply)"


class LauncherApp:
    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title("AI Thoughts — Bridge Launcher")
        self.root.minsize(520, 480)
        self.root.geometry("640x560")

        self.cfg = load_bridge_config()
        self.proc: subprocess.Popen | None = None
        self._log_q: queue.Queue[str] = queue.Queue()
        self._busy = False
        self._prev_provider_id: str | None = None

        self._build()
        self._load_into_form()
        self._poll_log()
        self._poll_proc()
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build(self) -> None:
        pad = {"padx": 10, "pady": 4}
        frm = ttk.Frame(self.root, padding=10)
        frm.pack(fill=tk.BOTH, expand=True)

        ttk.Label(frm, text="Provider").grid(row=0, column=0, sticky=tk.W, **pad)
        self.provider_var = tk.StringVar()
        labels = []
        self._label_to_id: dict[str, str] = {}
        for pid in PROVIDER_ORDER:
            p = self.cfg["providers"].get(pid) or {}
            lab = str(p.get("label") or pid)
            labels.append(lab)
            self._label_to_id[lab] = pid
        self.provider_combo = ttk.Combobox(
            frm, textvariable=self.provider_var, values=labels, state="readonly", width=48
        )
        self.provider_combo.grid(row=0, column=1, columnspan=2, sticky=tk.EW, **pad)
        self.provider_combo.bind("<<ComboboxSelected>>", self._on_provider_change)

        ttk.Label(frm, text="Base URL").grid(row=1, column=0, sticky=tk.W, **pad)
        self.url_var = tk.StringVar()
        ttk.Entry(frm, textvariable=self.url_var, width=50).grid(
            row=1, column=1, columnspan=2, sticky=tk.EW, **pad
        )

        ttk.Label(frm, text="Model").grid(row=2, column=0, sticky=tk.W, **pad)
        self.model_var = tk.StringVar()
        self.model_combo = ttk.Combobox(frm, textvariable=self.model_var, width=40)
        self.model_combo.grid(row=2, column=1, sticky=tk.EW, **pad)
        ttk.Button(frm, text="Refresh models", command=self._refresh_models).grid(
            row=2, column=2, sticky=tk.E, **pad
        )

        ttk.Label(frm, text="API key").grid(row=3, column=0, sticky=tk.W, **pad)
        self.key_var = tk.StringVar()
        self.key_entry = ttk.Entry(frm, textvariable=self.key_var, show="*", width=50)
        self.key_entry.grid(row=3, column=1, columnspan=2, sticky=tk.EW, **pad)

        self.key_hint = ttk.Label(
            frm,
            text="Cloud providers need a key. Ollama / LM Studio usually do not.",
            wraplength=520,
        )
        self.key_hint.grid(row=4, column=0, columnspan=3, sticky=tk.W, **pad)

        btn_row = ttk.Frame(frm)
        btn_row.grid(row=5, column=0, columnspan=3, sticky=tk.EW, pady=8)
        ttk.Button(btn_row, text="Save", command=self._save).pack(side=tk.LEFT, padx=4)
        ttk.Button(btn_row, text="Test connection", command=self._test).pack(side=tk.LEFT, padx=4)
        ttk.Button(btn_row, text="Start Bridge", command=self._start).pack(side=tk.LEFT, padx=4)
        ttk.Button(btn_row, text="Stop", command=self._stop).pack(side=tk.LEFT, padx=4)

        self.status_var = tk.StringVar(value="Stopped")
        ttk.Label(frm, textvariable=self.status_var, font=("", 10, "bold")).grid(
            row=6, column=0, columnspan=3, sticky=tk.W, **pad
        )

        ttk.Label(frm, text="Log").grid(row=7, column=0, sticky=tk.W, **pad)
        self.log = tk.Text(frm, height=16, wrap=tk.WORD, state=tk.DISABLED)
        self.log.grid(row=8, column=0, columnspan=3, sticky=tk.NSEW, **pad)
        scroll = ttk.Scrollbar(frm, command=self.log.yview)
        scroll.grid(row=8, column=3, sticky=tk.NS)
        self.log.configure(yscrollcommand=scroll.set)

        frm.columnconfigure(1, weight=1)
        frm.rowconfigure(8, weight=1)

        self._append_log(f"Config file: {CONFIG_PATH}")
        self._append_log("Pick a provider -> Save -> Test -> Start Bridge. Then play PZ.")

    def _active_id(self) -> str:
        lab = self.provider_var.get()
        return self._label_to_id.get(lab, self.cfg.get("active_provider") or "deepseek")

    def _load_into_form(self) -> None:
        pid = self.cfg.get("active_provider") or "deepseek"
        p = self.cfg["providers"].get(pid) or {}
        label = str(p.get("label") or pid)
        if label not in self._label_to_id:
            self._label_to_id[label] = pid
            vals = list(self.provider_combo["values"])
            if label not in vals:
                self.provider_combo["values"] = list(vals) + [label]
        self.provider_var.set(label)
        self.url_var.set(str(p.get("base_url") or ""))
        self.model_var.set(str(p.get("model") or ""))
        self.key_var.set(str(p.get("api_key") or ""))
        self._prev_provider_id = pid
        self._update_key_hint()

    def _on_provider_change(self, _evt: Any = None) -> None:
        # Save current fields into the PREVIOUS provider slot
        prev = self._prev_provider_id
        if prev and prev in self.cfg["providers"]:
            p = self.cfg["providers"][prev]
            p["base_url"] = self.url_var.get().strip()
            p["model"] = self.model_var.get().strip()
            p["api_key"] = self.key_var.get().strip()
        pid = self._active_id()
        self.cfg["active_provider"] = pid
        p = self.cfg["providers"].get(pid) or {}
        self.url_var.set(str(p.get("base_url") or ""))
        self.model_var.set(str(p.get("model") or ""))
        self.key_var.set(str(p.get("api_key") or ""))
        self._prev_provider_id = pid
        self._update_key_hint()
    def _update_key_hint(self) -> None:
        pid = self._active_id()
        p = self.cfg["providers"].get(pid) or {}
        if p.get("requires_key"):
            self.key_hint.configure(
                text="This provider needs an API key (paste above, then Save)."
            )
        else:
            self.key_hint.configure(
                text="Local provider — API key optional (placeholder ok)."
            )

    def _form_into_cfg(self, keep_active: bool = True) -> None:
        pid = self._active_id()
        if keep_active:
            self.cfg["active_provider"] = pid
        if pid not in self.cfg["providers"]:
            self.cfg["providers"][pid] = {}
        p = self.cfg["providers"][pid]
        p["base_url"] = self.url_var.get().strip()
        p["model"] = self.model_var.get().strip()
        p["api_key"] = self.key_var.get().strip()
        if "requires_key" not in p:
            from llm_config import DEFAULT_PROVIDERS

            p["requires_key"] = bool(
                (DEFAULT_PROVIDERS.get(pid) or {}).get("requires_key", False)
            )
        if "label" not in p or not p["label"]:
            p["label"] = pid

    def _append_log(self, line: str) -> None:
        self.log.configure(state=tk.NORMAL)
        self.log.insert(tk.END, line.rstrip() + "\n")
        self.log.see(tk.END)
        self.log.configure(state=tk.DISABLED)

    def _save(self) -> None:
        try:
            self._form_into_cfg(keep_active=True)
            save_bridge_config(self.cfg)
            self.cfg = load_bridge_config()
            self._append_log(f"Saved -> {CONFIG_PATH}")
            self.status_var.set(
                "Saved (bridge hot-reloads on next thought; Restart if unsure)"
            )
        except Exception as e:
            self._append_log(f"Save failed: {e}")
            messagebox.showerror("Save failed", str(e))

    def _run_bg(self, title: str, fn) -> None:
        if self._busy:
            self._append_log("Busy — wait for the current task.")
            return
        self._busy = True

        def worker() -> None:
            try:
                fn()
            except Exception as e:
                self._log_q.put(f"{title} failed: {e}")
                self._log_q.put(traceback.format_exc())
            finally:
                self._busy = False

        threading.Thread(target=worker, daemon=True).start()

    def _refresh_models(self) -> None:
        self._form_into_cfg(keep_active=True)
        url = self.url_var.get().strip()
        key = self.key_var.get().strip()

        def job() -> None:
            self._log_q.put(f"Refreshing models from {url} …")
            ids = list_models(url, key)
            self._log_q.put(f"Found {len(ids)} model(s).")
            self.root.after(0, lambda: self._apply_models(ids))

        self._run_bg("Refresh models", job)

    def _apply_models(self, ids: list[str]) -> None:
        self.model_combo["values"] = ids
        if ids and self.model_var.get() not in ids:
            self.model_var.set(ids[0])

    def _test(self) -> None:
        self._form_into_cfg(keep_active=True)
        url = self.url_var.get().strip()
        key = self.key_var.get().strip()
        model = self.model_var.get().strip()
        pid = self._active_id()
        p = self.cfg["providers"].get(pid) or {}
        if p.get("requires_key") and placeholder_key(key):
            messagebox.showwarning("API key", "Paste an API key for this provider first.")
            return
        if not model:
            messagebox.showwarning("Model", "Set a model name first.")
            return

        def job() -> None:
            self._log_q.put(f"Testing {pid} model={model} …")
            reply = test_chat(url, key, model)
            self._log_q.put(f"Test OK — reply: {reply[:120]}")

        self._run_bg("Test", job)

    def _start(self) -> None:
        self._save()
        if self.proc and self.proc.poll() is None:
            self._append_log("Bridge already running.")
            return
        py = _venv_python()
        if not BRIDGE_SCRIPT.exists():
            messagebox.showerror("Missing", f"Not found: {BRIDGE_SCRIPT}")
            return
        try:
            creationflags = 0
            if sys.platform == "win32":
                creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
            self.proc = subprocess.Popen(
                [str(py), str(BRIDGE_SCRIPT)],
                cwd=str(REPO),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                creationflags=creationflags,
            )
            self.status_var.set(f"Running (pid {self.proc.pid})")
            self._append_log(f"Started bridge pid={self.proc.pid} via {py}")
            threading.Thread(target=self._reader_thread, daemon=True).start()
        except Exception as e:
            self._append_log(f"Start failed: {e}")
            messagebox.showerror("Start failed", str(e))

    def _reader_thread(self) -> None:
        proc = self.proc
        if not proc or not proc.stdout:
            return
        for line in proc.stdout:
            self._log_q.put(line.rstrip("\n"))
        code = proc.poll()
        self._log_q.put(f"[bridge exited code={code}]")

    def _stop(self) -> None:
        if not self.proc or self.proc.poll() is not None:
            self.status_var.set("Stopped")
            self._append_log("Bridge not running.")
            self.proc = None
            return
        try:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
            self._append_log("Bridge stopped.")
        except Exception as e:
            self._append_log(f"Stop error: {e}")
        self.proc = None
        self.status_var.set("Stopped")

    def _poll_log(self) -> None:
        try:
            while True:
                line = self._log_q.get_nowait()
                self._append_log(line)
        except queue.Empty:
            pass
        self.root.after(200, self._poll_log)

    def _poll_proc(self) -> None:
        if self.proc is not None:
            code = self.proc.poll()
            if code is not None:
                self.status_var.set(f"Stopped (exit {code})")
                self.proc = None
            else:
                self.status_var.set(f"Running (pid {self.proc.pid})")
        self.root.after(1000, self._poll_proc)

    def _on_close(self) -> None:
        if self.proc and self.proc.poll() is None:
            if messagebox.askyesno(
                "Quit",
                "Bridge is still running. Stop it and quit?",
            ):
                self._stop()
                self.root.destroy()
            return
        self.root.destroy()

    def run(self) -> None:
        self.root.mainloop()


def main() -> int:
    # Seed config file from defaults if missing
    if not CONFIG_PATH.exists():
        save_bridge_config(default_config())
    app = LauncherApp()
    app.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
