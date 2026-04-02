"""
StatusBar: mini-ventana flotante siempre encima, arrastrable.
Muestra el estado actual (BLOQUEANDO / EN PAUSA / LIBRE) con punto pulsante.
"""
from __future__ import annotations

from typing import Callable
import tkinter as tk

from .widgets import T, PulsingDot


class StatusBar:
    """Floating mini-window que siempre queda por encima del resto."""

    def __init__(self, root: tk.Tk, on_open: Callable[[], None]):
        self.root     = root
        self._on_open = on_open

        self.bar = tk.Toplevel(root)
        self.bar.overrideredirect(True)
        self.bar.attributes("-topmost", True)
        self.bar.attributes("-alpha", 0.95)
        self.bar.configure(bg=T.BORDER)

        sw = root.winfo_screenwidth()
        sh = root.winfo_screenheight()
        w, h = 240, 36
        self.bar.geometry(f"{w}x{h}+{sw - w - 14}+{sh - h - 54}")

        self._inner = tk.Frame(self.bar, bg=T.BG_BASE)
        self._inner.pack(fill="both", expand=True, padx=1, pady=1)

        self._dot = PulsingDot(self._inner, bg=T.BG_BASE)
        self._dot.pack(side="left", padx=(10, 6), pady=14)

        self._label = tk.Label(
            self._inner, text="FocusGuard",
            font=("Segoe UI", 9, "bold"),
            bg=T.BG_BASE, fg=T.TEXT_PRIMARY, padx=0,
        )
        self._label.pack(side="left", fill="x", expand=True)

        self._btn_wrap = tk.Frame(self._inner, bg=T.BORDER_FOCUS)
        self._btn_wrap.pack(side="right", padx=8, pady=6)

        self._btn = tk.Button(
            self._btn_wrap, text="abrir",
            font=("Segoe UI", 7),
            bg=T.BG_SURFACE2, fg=T.TEXT_MUTED2,
            relief="flat", bd=0, cursor="hand2",
            padx=8, pady=2,
            command=self._open_main,
        )
        self._btn.pack(padx=1, pady=1)
        self._btn.bind("<Enter>", lambda e: self._btn.config(
            bg=T.BORDER, fg=T.TEXT_PRIMARY))
        self._btn.bind("<Leave>", lambda e: self._btn.config(
            bg=T.BG_SURFACE2, fg=T.TEXT_MUTED2))

        for widget in (self._inner, self._label):
            widget.bind("<ButtonPress-1>", self._drag_start)
            widget.bind("<B1-Motion>",     self._drag_motion)
        self._dx = self._dy = 0

        # Último estado para re-aplicar tras refresh de tema
        self._last_blocking = False
        self._last_paused   = False

    # ── Arrastre ──────────────────────────────────────────────────────────────
    def _drag_start(self, e) -> None:
        self._dx = e.x_root - self.bar.winfo_x()
        self._dy = e.y_root - self.bar.winfo_y()

    def _drag_motion(self, e) -> None:
        self.bar.geometry(f"+{e.x_root - self._dx}+{e.y_root - self._dy}")

    def _open_main(self) -> None:
        self._on_open()

    # ── Tema ──────────────────────────────────────────────────────────────────
    def refresh_theme(self) -> None:
        """Actualiza colores de la barra flotante al cambiar de tema."""
        self.bar.configure(bg=T.BORDER)
        self._inner.configure(bg=T.BG_BASE)
        self._dot.configure(bg=T.BG_BASE)
        self._label.configure(bg=T.BG_BASE)
        self._btn_wrap.configure(bg=T.BORDER_FOCUS)
        self._btn.configure(bg=T.BG_SURFACE2, fg=T.TEXT_MUTED2)
        self.update_status(self._last_blocking, self._last_paused)

    # ── Estado ────────────────────────────────────────────────────────────────
    def update_status(self, blocking: bool, paused: bool = False) -> None:
        self._last_blocking = blocking
        self._last_paused   = paused
        self._dot.set_state(blocking, paused)
        if paused:
            self._label.config(text="●  EN PAUSA",   fg=T.ACCENT_GOLD,
                               bg=T.BG_BASE)
        elif blocking:
            self._label.config(text="●  BLOQUEANDO", fg=T.ACCENT_RED,
                               bg=T.BG_BASE)
        else:
            self._label.config(text="●  LIBRE",      fg=T.ACCENT_GREEN,
                               bg=T.BG_BASE)
