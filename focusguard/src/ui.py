"""
MainWindow v3 — FocusGuard con 4 tabs y soporte de tema dark / light.

Tabs: Inicio · Calendario · Smart · Ajustes
Tema: negro + blanco (dark) | blanco + gris (light)
Acento interactivo: azul #0a84ff / #007aff
"""
from __future__ import annotations

import logging
import threading
import tkinter as tk
from datetime import datetime, timedelta
from tkinter import messagebox, ttk
from typing import TYPE_CHECKING, List, Optional

if TYPE_CHECKING:
    from .blocker import BlockerThread
    from .tray import StatusBar

from . import config as cfg
from .models import Task, TaskStatus, TaskMode, BlockSession
from .repository import TaskRepository
from .scheduler import SchedulerService
from .widgets import (
    T, apply_dark, apply_light, is_dark,
    AnimatedBar, PulsingDot, CheckBox, lerp_color, spaced,
)

log = logging.getLogger("focusguard.ui")
MEXICO_TZ = cfg.MEXICO_TZ


# ── Notificación ───────────────────────────────────────────────────────────────
def _notify(title: str, message: str) -> None:
    try:
        from plyer import notification
        notification.notify(title=title, message=message, app_name="FocusGuard", timeout=6)
        return
    except Exception:
        pass
    try:
        from win10toast import ToastNotifier
        ToastNotifier().show_toast(title, message, duration=5, threaded=True)
    except Exception:
        log.info(f"Notif: {title} — {message}")


# ── Scroll suave ───────────────────────────────────────────────────────────────
class SmoothScroller:
    def __init__(self, canvas: tk.Canvas):
        self.canvas     = canvas
        self._target    = 0.0
        self._current   = 0.0
        self._animating = False
        self._ease      = 0.18

    def scroll(self, delta: float) -> None:
        try:
            top, _ = self.canvas.yview()
        except Exception:
            return
        self._current = top
        self._target  = max(0.0, min(1.0, top + delta * 0.08))
        if not self._animating:
            self._animate()

    def _animate(self) -> None:
        diff = self._target - self._current
        if abs(diff) < 0.001:
            self._current = self._target
            try:
                self.canvas.yview_moveto(self._current)
            except tk.TclError:
                pass
            self._animating = False
            return
        self._animating  = True
        self._current   += diff * self._ease
        try:
            self.canvas.yview_moveto(self._current)
            self.canvas.after(16, self._animate)
        except tk.TclError:
            self._animating = False


# ══════════════════════════════════════════════════════════════════════════════
# MainWindow
# ══════════════════════════════════════════════════════════════════════════════
class MainWindow:
    _APP_PH = "Nombre del proceso (.exe)"

    def __init__(self, root: tk.Tk, status_bar: "StatusBar", blocker: "BlockerThread"):
        self.root       = root
        self.status_bar = status_bar
        self.blocker    = blocker
        self._repo      = TaskRepository()
        self._sched     = SchedulerService()

        self._was_blocking:  bool       = cfg.is_blocking_active()
        self._history_saved: bool       = False
        self._after_id:      str | None = None
        self._content:       Optional[tk.Frame] = None

        # Aplicar tema guardado
        if cfg.get_dark_mode():
            apply_dark()
        else:
            apply_light()

        # Migrar tareas antiguas si existen
        old_data = cfg.get_data()
        if old_data.get("tasks"):
            self._repo.migrate_from_old_config(old_data["tasks"])

        root.title("FocusGuard")
        root.resizable(True, True)
        root.minsize(780, 560)
        root.protocol("WM_DELETE_WINDOW", self._on_close)

        self._build()
        self._fade_in()
        self._refresh()

    # ── Fade-in ────────────────────────────────────────────────────────────────
    def _fade_in(self, alpha: float = 0.0) -> None:
        self.root.attributes("-alpha", alpha)
        if alpha < 1.0:
            self.root.after(12, lambda: self._fade_in(min(1.0, alpha + 0.07)))

    # ── Reconstruir todo (usado al cambiar tema) ───────────────────────────────
    def _build(self) -> None:
        if self._content:
            self._content.destroy()

        self.root.configure(bg=T.BG_BASE)
        self._content = tk.Frame(self.root, bg=T.BG_BASE)
        self._content.pack(fill="both", expand=True)
        self.root.geometry("880x640")

        self._build_header()
        self._build_status_strip()
        self._build_notebook()

    # ══════════════════════════════════════════════════════════════════════════
    # HEADER
    # ══════════════════════════════════════════════════════════════════════════
    def _build_header(self) -> None:
        p = self._content

        header = tk.Frame(p, bg=T.BG_BASE)
        header.pack(fill="x", padx=20, pady=(14, 0))

        # — Izquierda: dot + título —
        left = tk.Frame(header, bg=T.BG_BASE)
        left.pack(side="left")
        self._dot = PulsingDot(left, bg=T.BG_BASE)
        self._dot.pack(side="left", padx=(0, 10))
        tk.Label(left, text="FocusGuard",
                 font=("Segoe UI", 13, "bold"),
                 bg=T.BG_BASE, fg=T.TEXT_PRIMARY).pack(side="left")
        self._status_pill = tk.Label(left, text="",
                                     font=("Segoe UI", 8, "bold"),
                                     bg=T.BG_BASE, fg=T.TEXT_MUTED,
                                     padx=8, pady=2)
        self._status_pill.pack(side="left", padx=(12, 0))

        # — Derecha: hora límite + reloj —
        right = tk.Frame(header, bg=T.BG_BASE)
        right.pack(side="right", anchor="center")

        tk.Label(right, text="Hora límite",
                 font=("Segoe UI", 8), bg=T.BG_BASE,
                 fg=T.TEXT_MUTED2).pack(side="left", padx=(0, 6))

        self._hour_var = tk.IntVar(value=cfg.get_unlock_hour())
        spin_wrap = tk.Frame(right, bg=T.BORDER)
        spin_wrap.pack(side="left")
        self._hour_spin = tk.Spinbox(
            spin_wrap, from_=0, to=23, textvariable=self._hour_var,
            width=3, font=("Segoe UI", 10, "bold"),
            bg=T.BG_INPUT, fg=T.ACCENT_BLUE,
            buttonbackground=T.BG_SURFACE2,
            relief="flat", bd=0, highlightthickness=0,
            insertbackground=T.ACCENT_BLUE, justify="center",
        )
        self._hour_spin.pack(padx=1, pady=1)
        tk.Label(right, text="h", font=("Segoe UI", 9),
                 bg=T.BG_BASE, fg=T.TEXT_MUTED2).pack(side="left", padx=(4, 16))

        self._clock_lbl = tk.Label(right, text="",
                                   font=("Segoe UI", 11),
                                   bg=T.BG_BASE, fg=T.TEXT_MUTED2)
        self._clock_lbl.pack(side="left")

        self._setting_hour = False
        self._hour_var.trace_add("write", lambda *_: self._set_unlock_hour())

        # Separador
        tk.Frame(p, bg=T.SEPARATOR, height=1).pack(fill="x", pady=(10, 0))

    # ══════════════════════════════════════════════════════════════════════════
    # STATUS STRIP
    # ══════════════════════════════════════════════════════════════════════════
    def _build_status_strip(self) -> None:
        p = self._content

        strip = tk.Frame(p, bg=T.BG_BASE)
        strip.pack(fill="x", padx=20, pady=(10, 4))

        left = tk.Frame(strip, bg=T.BG_BASE)
        left.pack(side="left")

        self._status_lbl = tk.Label(left, text="",
                                    font=("Segoe UI", 20, "bold"),
                                    bg=T.BG_BASE, fg=T.TEXT_PRIMARY)
        self._status_lbl.pack(anchor="w")

        self._status_desc = tk.Label(left, text="",
                                     font=("Segoe UI", 8),
                                     bg=T.BG_BASE, fg=T.TEXT_MUTED2)
        self._status_desc.pack(anchor="w")

        self._pause_btn = tk.Button(left, text="Pausar 15 min",
                                    font=("Segoe UI", 8), bg=T.BG_BASE,
                                    fg=T.TEXT_MUTED, relief="flat", bd=0,
                                    cursor="hand2", padx=0, pady=0,
                                    command=self._toggle_pause)
        self._pause_btn.pack(anchor="w", pady=(2, 0))
        self._pause_btn.bind("<Enter>", lambda e: self._pause_btn.config(fg=T.ACCENT_BLUE))
        self._pause_btn.bind("<Leave>", lambda e: self._pause_btn.config(fg=T.TEXT_MUTED))

        right = tk.Frame(strip, bg=T.BG_BASE)
        right.pack(side="right", anchor="e")

        self._count_lbl = tk.Label(right, text="",
                                   font=("Segoe UI", 9), bg=T.BG_BASE,
                                   fg=T.TEXT_MUTED2, anchor="e")
        self._count_lbl.pack(anchor="e")
        self._streak_lbl = tk.Label(right, text="",
                                    font=("Segoe UI", 8, "bold"),
                                    bg=T.BG_BASE, fg=T.ACCENT_BLUE, anchor="e")
        self._streak_lbl.pack(anchor="e")

        # Barra de progreso
        self._bar = AnimatedBar(p, height=4, bg=T.SEPARATOR)
        self._bar.pack(fill="x", padx=20, pady=(6, 0))
        tk.Frame(p, bg=T.SEPARATOR, height=1).pack(fill="x", padx=20, pady=(6, 0))

    # ══════════════════════════════════════════════════════════════════════════
    # NOTEBOOK
    # ══════════════════════════════════════════════════════════════════════════
    def _build_notebook(self) -> None:
        p = self._content

        style = ttk.Style()
        style.theme_use("default")
        nb_bg     = T.BG_BASE
        tab_bg    = T.BG_SURFACE2
        tab_sel   = T.BG_BASE
        tab_fg    = T.TEXT_MUTED2
        tab_selfg = T.TEXT_PRIMARY

        style.configure("FG.TNotebook",
                         background=nb_bg, borderwidth=0,
                         tabmargins=[0, 4, 0, 0])
        style.configure("FG.TNotebook.Tab",
                         background=tab_bg, foreground=tab_fg,
                         padding=[18, 7], font=("Segoe UI", 9),
                         borderwidth=0, relief="flat")
        style.map("FG.TNotebook.Tab",
                  background=[("selected", tab_sel)],
                  foreground=[("selected", tab_selfg)],
                  font=[("selected", ("Segoe UI", 9, "bold"))])

        self._nb = ttk.Notebook(p, style="FG.TNotebook")
        self._nb.pack(fill="both", expand=True)

        self._tab_home     = tk.Frame(self._nb, bg=T.BG_BASE)
        self._tab_calendar = tk.Frame(self._nb, bg=T.BG_BASE)
        self._tab_smart    = tk.Frame(self._nb, bg=T.BG_BASE)
        self._tab_settings = tk.Frame(self._nb, bg=T.BG_BASE)

        self._nb.add(self._tab_home,     text="  ⌂  Inicio  ")
        self._nb.add(self._tab_calendar, text="  ◫  Calendario  ")
        self._nb.add(self._tab_smart,    text="  ⚡  Smart  ")
        self._nb.add(self._tab_settings, text="  ⚙  Ajustes  ")

        self._build_home_tab()
        self._build_calendar_tab()
        self._build_smart_tab()
        self._build_settings_tab()

        self._nb.bind("<<NotebookTabChanged>>", self._on_tab_change)

    def _on_tab_change(self, _event=None) -> None:
        if self._nb.index("current") == 1:
            self._render_cal_tasks()

    # ══════════════════════════════════════════════════════════════════════════
    # TAB: INICIO
    # ══════════════════════════════════════════════════════════════════════════
    def _build_home_tab(self) -> None:
        p = self._tab_home

        # ── Progress card ──────────────────────────────────────────────────────
        card_wrap = tk.Frame(p, bg=T.BORDER)
        card_wrap.pack(fill="x", padx=16, pady=(14, 0))
        card = tk.Frame(card_wrap, bg=T.BG_SURFACE2)
        card.pack(fill="x", padx=1, pady=1)

        # Fila 1: etiqueta + badge sesión
        row1 = tk.Frame(card, bg=T.BG_SURFACE2)
        row1.pack(fill="x", padx=16, pady=(12, 0))
        tk.Label(row1, text="PROGRESO DE HOY",
                 font=("Segoe UI", 7, "bold"),
                 bg=T.BG_SURFACE2, fg=T.TEXT_MUTED2).pack(side="left")
        self._session_badge = tk.Label(row1, text="",
                                       font=("Segoe UI", 8, "bold"),
                                       bg=T.BG_SURFACE2, fg=T.ACCENT_GREEN,
                                       padx=8, pady=2)
        self._session_badge.pack(side="right")

        # Fila 2: contador grande + porcentaje
        row2 = tk.Frame(card, bg=T.BG_SURFACE2)
        row2.pack(fill="x", padx=16, pady=(6, 0))
        self._home_done_lbl = tk.Label(row2, text="0",
                                       font=("Segoe UI", 38, "bold"),
                                       bg=T.BG_SURFACE2, fg=T.TEXT_PRIMARY)
        self._home_done_lbl.pack(side="left")
        self._home_total_lbl = tk.Label(row2, text=" / 0 tareas",
                                        font=("Segoe UI", 12),
                                        bg=T.BG_SURFACE2, fg=T.TEXT_MUTED2)
        self._home_total_lbl.pack(side="left", anchor="s", pady=(0, 10))
        self._home_pct_lbl = tk.Label(row2, text="",
                                      font=("Segoe UI", 20, "bold"),
                                      bg=T.BG_SURFACE2, fg=T.ACCENT_BLUE)
        self._home_pct_lbl.pack(side="right", padx=16)

        # Barra de progreso
        self._home_bar = AnimatedBar(card, height=5, bg=T.SEPARATOR)
        self._home_bar.pack(fill="x", padx=16, pady=(10, 0))

        # Fila focus blocks
        fb_row = tk.Frame(card, bg=T.BG_SURFACE2)
        fb_row.pack(fill="x", padx=16, pady=(10, 14))
        tk.Label(fb_row, text="Focus blocks",
                 font=("Segoe UI", 8), bg=T.BG_SURFACE2,
                 fg=T.TEXT_MUTED2).pack(side="left")
        self._dots_frame = tk.Frame(fb_row, bg=T.BG_SURFACE2)
        self._dots_frame.pack(side="left", padx=(10, 0))
        self._blocks_lbl = tk.Label(fb_row, text="",
                                    font=("Segoe UI", 8),
                                    bg=T.BG_SURFACE2, fg=T.TEXT_MUTED2)
        self._blocks_lbl.pack(side="right")

        # ── Sección tareas de hoy ──────────────────────────────────────────────
        self._section_header(p, "Tareas de hoy", right_var="_today_badge")
        self._home_tasks_frame, self._home_canvas = self._make_scrollable(p)
        self._home_scroller = SmoothScroller(self._home_canvas)
        self._home_canvas.bind(
            "<MouseWheel>",
            lambda e: self._home_scroller.scroll(-1 if e.delta > 0 else 1))

        # Input añadir tarea
        add_row = tk.Frame(p, bg=T.BG_BASE)
        add_row.pack(fill="x", padx=16, pady=(6, 12))
        wrap, self._home_entry = self._make_entry(add_row, "Añadir tarea para hoy…")
        wrap.pack(side="left", fill="x", expand=True)
        self._home_entry.bind("<Return>", lambda _: self._home_add_task())
        self._make_add_btn(add_row, self._home_add_task).pack(
            side="right", padx=(8, 0))

    # ══════════════════════════════════════════════════════════════════════════
    # TAB: CALENDARIO
    # ══════════════════════════════════════════════════════════════════════════
    def _build_calendar_tab(self) -> None:
        p = self._tab_calendar
        self._cal_date = datetime.now()
        self._tkcal_available = False

        try:
            from tkcalendar import Calendar as TkCal
            self._tkcal_available = True

            cal_wrap = tk.Frame(p, bg=T.BORDER)
            cal_wrap.pack(fill="x", padx=16, pady=(14, 0))
            inner_cal = tk.Frame(cal_wrap, bg=T.BG_SURFACE2)
            inner_cal.pack(fill="x", padx=1, pady=1)

            dark = is_dark()
            self._tkcal = TkCal(
                inner_cal,
                selectmode="day",
                year=self._cal_date.year,
                month=self._cal_date.month,
                day=self._cal_date.day,
                background=T.BG_SURFACE2,
                foreground=T.TEXT_PRIMARY,
                bordercolor=T.BG_SURFACE2,
                headersbackground=T.BG_BASE if dark else T.BG_SURFACE,
                headersforeground=T.TEXT_MUTED2,
                selectbackground=T.ACCENT_BLUE,
                selectforeground="#ffffff",
                weekendforeground=T.TEXT_MUTED2,
                othermonthforeground=T.TEXT_MUTED,
                othermonthbackground=T.BG_SURFACE2,
                normalbackground=T.BG_SURFACE2,
                normalforeground=T.TEXT_PRIMARY,
                font=("Segoe UI", 9),
                showweeknumbers=False,
            )
            self._tkcal.pack(fill="x", padx=6, pady=6)
            self._tkcal.bind("<<CalendarSelected>>", self._on_cal_select)
        except ImportError:
            tk.Label(p,
                     text="⚠  Instala tkcalendar para ver el calendario:\n"
                          "     pip install tkcalendar",
                     font=("Segoe UI", 10), bg=T.BG_BASE,
                     fg=T.ACCENT_GOLD, justify="left").pack(padx=20, pady=20, anchor="w")

        # Header del día seleccionado
        day_hdr = tk.Frame(p, bg=T.BG_BASE)
        day_hdr.pack(fill="x", padx=16, pady=(12, 4))
        self._cal_day_lbl = tk.Label(day_hdr, text="",
                                     font=("Segoe UI", 11, "bold"),
                                     bg=T.BG_BASE, fg=T.TEXT_PRIMARY)
        self._cal_day_lbl.pack(side="left")
        self._cal_count_lbl = tk.Label(day_hdr, text="",
                                       font=("Segoe UI", 8),
                                       bg=T.BG_BASE, fg=T.TEXT_MUTED2)
        self._cal_count_lbl.pack(side="right")
        tk.Frame(p, bg=T.SEPARATOR, height=1).pack(fill="x", padx=16)

        self._cal_tasks_frame, self._cal_canvas = self._make_scrollable(p)
        self._cal_scroller = SmoothScroller(self._cal_canvas)
        self._cal_canvas.bind(
            "<MouseWheel>",
            lambda e: self._cal_scroller.scroll(-1 if e.delta > 0 else 1))

        add_row = tk.Frame(p, bg=T.BG_BASE)
        add_row.pack(fill="x", padx=16, pady=(6, 12))
        wrap, self._cal_entry = self._make_entry(add_row, "Añadir tarea para este día…")
        wrap.pack(side="left", fill="x", expand=True)
        self._cal_entry.bind("<Return>", lambda _: self._cal_add_task())
        self._make_add_btn(add_row, self._cal_add_task).pack(side="right", padx=(8, 0))

        self._render_cal_tasks()

    def _on_cal_select(self, _=None) -> None:
        if not self._tkcal_available:
            return
        sel = self._tkcal.selection_get()
        self._cal_date = datetime(sel.year, sel.month, sel.day)
        self._render_cal_tasks()

    # ══════════════════════════════════════════════════════════════════════════
    # TAB: SMART
    # ══════════════════════════════════════════════════════════════════════════
    def _build_smart_tab(self) -> None:
        p = self._tab_smart
        self._smart_date   = datetime.now()
        self._smart_inputs: List[dict] = []

        # Tip card
        tip_wrap = tk.Frame(p, bg=T.ACCENT_BLUE)
        tip_wrap.pack(fill="x", padx=16, pady=(14, 0))
        tip_inner = tk.Frame(tip_wrap, bg=T.BG_SURFACE2)
        tip_inner.pack(fill="x", padx=1, pady=1)
        tk.Label(tip_inner,
                 text="⚡  Escribe tus tareas y FocusGuard las distribuye"
                      " automáticamente en bloques de 1½ hora (8:00 – 20:00).",
                 font=("Segoe UI", 9), bg=T.BG_SURFACE2, fg=T.TEXT_PRIMARY,
                 anchor="w", wraplength=700, justify="left",
                 pady=10, padx=12).pack(fill="x")

        # Selector de fecha
        date_bar = tk.Frame(p, bg=T.BG_BASE)
        date_bar.pack(fill="x", padx=16, pady=(12, 0))
        tk.Label(date_bar, text="Programar para:",
                 font=("Segoe UI", 9), bg=T.BG_BASE,
                 fg=T.TEXT_MUTED2).pack(side="left")
        self._smart_date_btn = self._link_btn(
            date_bar,
            self._smart_date.strftime("%A %d/%m/%Y"),
            self._smart_pick_date)
        self._smart_date_btn.pack(side="left", padx=(8, 0))

        tk.Frame(p, bg=T.SEPARATOR, height=1).pack(fill="x", padx=16, pady=(10, 0))

        # Lista de inputs (scrollable)
        self._smart_inner, self._smart_canvas = self._make_scrollable(p)
        self._smart_scroller = SmoothScroller(self._smart_canvas)
        self._smart_canvas.bind(
            "<MouseWheel>",
            lambda e: self._smart_scroller.scroll(-1 if e.delta > 0 else 1))

        # Botones
        btns = tk.Frame(p, bg=T.BG_BASE)
        btns.pack(fill="x", padx=16, pady=(8, 12))

        self._link_btn(btns, "+ Añadir otra tarea", self._smart_add_input,
                       side="left")

        sched_wrap = tk.Frame(btns, bg=T.ACCENT_BLUE)
        sched_wrap.pack(side="right")
        sched_btn = tk.Button(sched_wrap, text="  ⚡  Auto-Schedule  ",
                              font=("Segoe UI", 9, "bold"),
                              bg=T.BG_SURFACE2, fg=T.ACCENT_BLUE,
                              relief="flat", bd=0, cursor="hand2",
                              padx=6, pady=5,
                              command=self._smart_run)
        sched_btn.pack(padx=1, pady=1)
        sched_btn.bind("<Enter>", lambda e: sched_btn.config(bg=T.BORDER))
        sched_btn.bind("<Leave>", lambda e: sched_btn.config(bg=T.BG_SURFACE2))

        self._smart_add_input()

    def _smart_add_input(self) -> None:
        idx  = len(self._smart_inputs)
        wrap = tk.Frame(self._smart_inner, bg=T.BORDER)
        wrap.pack(fill="x", padx=4, pady=(4, 0))
        inner = tk.Frame(wrap, bg=T.BG_SURFACE2)
        inner.pack(fill="x", padx=1, pady=1)

        num_lbl = tk.Label(inner, text=f"{idx + 1}",
                           font=("Segoe UI", 10, "bold"),
                           bg=T.ACCENT_BLUE, fg="#ffffff",
                           width=3, pady=8)
        num_lbl.pack(side="left", fill="y")

        fields = tk.Frame(inner, bg=T.BG_SURFACE2)
        fields.pack(side="left", fill="x", expand=True, padx=(8, 4), pady=6)

        tw, te = self._make_entry(fields, "Título de la tarea")
        tw.pack(fill="x", pady=(0, 4))

        dw, de = self._make_entry(fields, "Descripción (opcional)")
        dw.pack(fill="x")

        del_btn = tk.Label(inner, text="✕", font=("Segoe UI", 11),
                           bg=T.BG_SURFACE2, fg=T.TEXT_MUTED,
                           cursor="hand2", padx=10)
        del_btn.pack(side="right", anchor="center")
        del_btn.bind("<Button-1>", lambda e, i=idx: self._smart_remove(i))
        del_btn.bind("<Enter>", lambda e: e.widget.config(fg=T.ACCENT_RED))
        del_btn.bind("<Leave>", lambda e: e.widget.config(fg=T.TEXT_MUTED))

        self._smart_inputs.append({"title": te, "desc": de, "wrap": wrap})
        self._smart_canvas.configure(scrollregion=self._smart_canvas.bbox("all"))

    def _smart_remove(self, idx: int) -> None:
        if idx < len(self._smart_inputs):
            self._smart_inputs.pop(idx)["wrap"].destroy()
            self._smart_canvas.configure(
                scrollregion=self._smart_canvas.bbox("all"))

    def _smart_pick_date(self) -> None:
        top = tk.Toplevel(self.root)
        top.title("Seleccionar fecha")
        top.configure(bg=T.BG_BASE)
        top.grab_set()
        try:
            from tkcalendar import Calendar as TkCal
            dark = is_dark()
            cal = TkCal(top, selectmode="day",
                        year=self._smart_date.year,
                        month=self._smart_date.month,
                        day=self._smart_date.day,
                        background=T.BG_SURFACE2,
                        foreground=T.TEXT_PRIMARY,
                        headersbackground=T.BG_BASE if dark else T.BG_SURFACE,
                        headersforeground=T.TEXT_MUTED2,
                        selectbackground=T.ACCENT_BLUE,
                        selectforeground="#ffffff",
                        font=("Segoe UI", 9),
                        showweeknumbers=False)
            cal.pack(padx=12, pady=12)

            def confirm():
                sel = cal.selection_get()
                self._smart_date = datetime(sel.year, sel.month, sel.day)
                self._smart_date_btn.config(
                    text=self._smart_date.strftime("%A %d/%m/%Y"))
                top.destroy()

            btn = tk.Button(top, text="Confirmar",
                            bg=T.ACCENT_BLUE, fg="#ffffff",
                            font=("Segoe UI", 9, "bold"),
                            relief="flat", bd=0, padx=16, pady=8,
                            command=confirm, cursor="hand2")
            btn.pack(pady=(0, 12))
        except ImportError:
            top.destroy()
            messagebox.showinfo("tkcalendar",
                                "pip install tkcalendar", parent=self.root)

    def _smart_run(self) -> None:
        ph = {"Título de la tarea", "Descripción (opcional)", ""}
        valid = [
            {"title": inp["title"].get().strip(),
             "desc":  inp["desc"].get().strip()}
            for inp in self._smart_inputs
            if inp["title"].get().strip() not in ph
        ]
        if not valid:
            messagebox.showwarning("Smart Scheduler",
                                   "Agrega al menos un título de tarea.",
                                   parent=self.root)
            return
        existing = self._repo.get_tasks_for_date(self._smart_date)
        bare = [Task(title=v["title"], description=v["desc"],
                     date=self._smart_date) for v in valid]
        scheduled = self._sched.schedule_tasks(bare, self._smart_date, existing)
        for t in scheduled:
            self._repo.save_task(t)
        messagebox.showinfo(
            "Smart Scheduler",
            f"✓  {len(scheduled)} tarea(s) agendadas para "
            f"{self._smart_date.strftime('%d/%m/%Y')}",
            parent=self.root)
        self._nb.select(1)
        self._cal_date = self._smart_date
        if self._tkcal_available:
            try:
                self._tkcal.selection_set(
                    self._smart_date.strftime("%m/%d/%y"))
            except Exception:
                pass
        self._schedule_refresh(immediate=True)

    # ══════════════════════════════════════════════════════════════════════════
    # TAB: AJUSTES
    # ══════════════════════════════════════════════════════════════════════════
    def _build_settings_tab(self) -> None:
        p = self._tab_settings

        canvas = tk.Canvas(p, bg=T.BG_BASE, bd=0, highlightthickness=0)
        sb = tk.Scrollbar(p, orient="vertical", command=canvas.yview,
                          bg=T.BG_SURFACE2, troughcolor=T.BG_BASE,
                          width=6, relief="flat", bd=0, highlightthickness=0)
        inner = tk.Frame(canvas, bg=T.BG_BASE)
        win_id = canvas.create_window((0, 0), window=inner, anchor="nw")
        inner.bind("<Configure>",
                   lambda _: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.bind("<Configure>",
                    lambda e: canvas.itemconfig(win_id, width=e.width))
        canvas.configure(yscrollcommand=sb.set)
        sb.pack(side="right", fill="y")
        canvas.pack(side="left", fill="both", expand=True)

        def sec(label: str) -> None:
            f = tk.Frame(inner, bg=T.BG_BASE)
            f.pack(fill="x", padx=20, pady=(18, 4))
            tk.Label(f, text=label.upper(), font=("Segoe UI", 7, "bold"),
                     bg=T.BG_BASE, fg=T.TEXT_MUTED2).pack(side="left")
            tk.Frame(f, bg=T.SEPARATOR, height=1).pack(
                side="left", fill="x", expand=True, padx=(10, 0))

        def row(label: str, sublabel: str, widget_fn) -> None:
            r = tk.Frame(inner, bg=T.BG_SURFACE2)
            r.pack(fill="x", padx=20, pady=2)
            txt = tk.Frame(r, bg=T.BG_SURFACE2)
            txt.pack(side="left", padx=14, pady=10)
            tk.Label(txt, text=label, font=("Segoe UI", 9),
                     bg=T.BG_SURFACE2, fg=T.TEXT_PRIMARY).pack(anchor="w")
            if sublabel:
                tk.Label(txt, text=sublabel, font=("Segoe UI", 7),
                         bg=T.BG_SURFACE2, fg=T.TEXT_MUTED2).pack(anchor="w")
            w = widget_fn(r)
            w.pack(side="right", padx=14, pady=8)

        # ── Apariencia ─────────────────────────────────────────────────────────
        sec("Apariencia")

        def make_theme(parent):
            var = tk.StringVar(value="dark" if is_dark() else "light")
            self._theme_var = var
            f = tk.Frame(parent, bg=T.BG_SURFACE2)
            for name, label in [("dark", "☾ Oscuro"), ("light", "☀ Claro")]:
                btn = tk.Radiobutton(
                    f, text=label, variable=var, value=name,
                    font=("Segoe UI", 9),
                    bg=T.BG_SURFACE2, fg=T.TEXT_PRIMARY,
                    selectcolor=T.BG_SURFACE2,
                    activebackground=T.BG_SURFACE2,
                    activeforeground=T.ACCENT_BLUE,
                    relief="flat", bd=0, cursor="hand2",
                    command=self._toggle_theme)
                btn.pack(side="left", padx=(0, 12))
            return f

        row("Tema de la aplicación", "Oscuro o claro", make_theme)

        # ── Sesión ─────────────────────────────────────────────────────────────
        sec("Sesión de trabajo")

        def make_spin(lo, hi, getter, setter, inc=1):
            def factory(parent):
                var = tk.IntVar(value=getter())
                def _save(*_):
                    try:
                        setter(int(var.get()))
                    except (ValueError, tk.TclError):
                        pass
                w = tk.Spinbox(parent, from_=lo, to=hi, textvariable=var,
                               increment=inc, width=5,
                               font=("Segoe UI", 10, "bold"),
                               bg=T.BG_INPUT, fg=T.ACCENT_BLUE,
                               buttonbackground=T.BG_SURFACE2,
                               relief="flat", bd=0, highlightthickness=0,
                               justify="center")
                var.trace_add("write", _save)
                return w
            return factory

        row("Hora límite del día",
            "La sesión se desbloquea automáticamente a esta hora",
            make_spin(0, 23, cfg.get_unlock_hour, cfg.set_unlock_hour))

        row("Duración del unlock por focus-block (min)",
            "Minutos libres al completar los bloques requeridos",
            make_spin(5, 120, cfg.get_unlock_duration,
                      cfg.set_unlock_duration, inc=5))

        row("Bloques necesarios para unlock",
            "Número de tareas completadas para activar el unlock",
            make_spin(1, 10, cfg.get_blocks_to_unlock,
                      cfg.set_blocks_to_unlock))

        # ── Apps bloqueadas ────────────────────────────────────────────────────
        sec("Apps bloqueadas")

        self._sett_apps_frame = tk.Frame(inner, bg=T.BG_BASE)
        self._sett_apps_frame.pack(fill="x", padx=20, pady=(0, 4))
        self._render_sett_apps()

        add_row = tk.Frame(inner, bg=T.BG_BASE)
        add_row.pack(fill="x", padx=20, pady=(0, 20))
        wrap, self._app_entry = self._make_entry(add_row, self._APP_PH)
        self._app_entry.bind("<FocusIn>",  self._app_fi)
        self._app_entry.bind("<FocusOut>", self._app_fo)
        self._app_entry.bind("<Return>",   lambda _: self._add_app())
        wrap.pack(side="left", fill="x", expand=True)
        self._make_add_btn(add_row, self._add_app).pack(
            side="right", padx=(8, 0))

    # ══════════════════════════════════════════════════════════════════════════
    # RENDER helpers
    # ══════════════════════════════════════════════════════════════════════════
    def _render_home_tasks(self, tasks: List[Task]) -> None:
        for w in self._home_tasks_frame.winfo_children():
            w.destroy()
        if not tasks:
            self._empty_state(self._home_tasks_frame,
                              "Sin tareas para hoy",
                              "Usa el campo de abajo para añadir una tarea.")
        else:
            for i, task in enumerate(tasks):
                self._task_card(self._home_tasks_frame, task)
                if i < len(tasks) - 1:
                    tk.Frame(self._home_tasks_frame,
                             bg=T.SEPARATOR, height=1).pack(fill="x")
        self._home_canvas.configure(scrollregion=self._home_canvas.bbox("all"))
        self._bind_mw(self._home_tasks_frame,
                      lambda e: self._home_scroller.scroll(
                          -1 if e.delta > 0 else 1))

    def _render_cal_tasks(self) -> None:
        for w in self._cal_tasks_frame.winfo_children():
            w.destroy()
        tasks = self._repo.get_tasks_for_date(self._cal_date)
        day_fmt = self._cal_date.strftime("%A, %d de %B de %Y")
        self._cal_day_lbl.config(text=day_fmt)
        self._cal_count_lbl.config(
            text=f"{len(tasks)} tarea{'s' if len(tasks) != 1 else ''}")

        if not tasks:
            self._empty_state(self._cal_tasks_frame,
                              "Sin tareas este día",
                              "Usa el campo de abajo para añadir una.")
        else:
            for i, task in enumerate(tasks):
                self._task_card(self._cal_tasks_frame, task)
                if i < len(tasks) - 1:
                    tk.Frame(self._cal_tasks_frame,
                             bg=T.SEPARATOR, height=1).pack(fill="x")

        self._cal_canvas.configure(scrollregion=self._cal_canvas.bbox("all"))
        self._bind_mw(self._cal_tasks_frame,
                      lambda e: self._cal_scroller.scroll(
                          -1 if e.delta > 0 else 1))
        self._update_cal_dots()

    def _update_cal_dots(self) -> None:
        if not self._tkcal_available:
            return
        try:
            dates = self._repo.dates_with_tasks()
            self._tkcal.calevent_remove("all")
            for d in dates:
                self._tkcal.calevent_create(d, "·", "task")
            self._tkcal.tag_config("task", foreground=T.ACCENT_BLUE)
        except Exception:
            pass

    def _render_sett_apps(self) -> None:
        for w in self._sett_apps_frame.winfo_children():
            w.destroy()
        apps = cfg.get_data().get("blocked_apps", [])
        if not apps:
            tk.Label(self._sett_apps_frame,
                     text="No hay apps bloqueadas todavía.",
                     font=("Segoe UI", 9, "italic"),
                     bg=T.BG_BASE, fg=T.TEXT_MUTED,
                     anchor="w").pack(fill="x", pady=4, padx=2)
            return
        for exe in apps:
            card = tk.Frame(self._sett_apps_frame, bg=T.BG_SURFACE2)
            card.pack(fill="x", pady=2)
            tk.Frame(card, bg=T.ACCENT_RED, width=3).pack(side="left", fill="y")
            tk.Label(card, text=f"  {exe}",
                     font=("Segoe UI", 9), bg=T.BG_SURFACE2,
                     fg=T.TEXT_PRIMARY, anchor="w", pady=10).pack(
                side="left", fill="x", expand=True)
            del_btn = tk.Label(card, text="✕", font=("Segoe UI", 11),
                               bg=T.BG_SURFACE2, fg=T.TEXT_MUTED,
                               cursor="hand2", padx=10)
            del_btn.pack(side="right")
            del_btn.bind("<Button-1>", lambda e, a=exe: self._remove_app(a))
            del_btn.bind("<Enter>",
                         lambda e: e.widget.config(fg=T.ACCENT_RED))
            del_btn.bind("<Leave>",
                         lambda e: e.widget.config(fg=T.TEXT_MUTED))

    # ── Task card ──────────────────────────────────────────────────────────────
    def _task_card(self, parent: tk.Frame, task: Task) -> None:
        is_done = task.status == TaskStatus.COMPLETED
        is_prog = task.status == TaskStatus.IN_PROGRESS

        card = tk.Frame(parent, bg=T.BG_SURFACE2)
        card.pack(fill="x")

        # Franja lateral de estado
        strip_color = (T.ACCENT_BLUE if is_prog
                       else T.ACCENT_GREEN if is_done
                       else T.SEPARATOR)
        tk.Frame(card, bg=strip_color, width=4).pack(side="left", fill="y")

        chk = CheckBox(card, checked=is_done, bg=T.BG_SURFACE2)
        chk.pack(side="left", padx=(10, 6), pady=12)

        info = tk.Frame(card, bg=T.BG_SURFACE2)
        info.pack(side="left", fill="x", expand=True, pady=8)

        title_fg = T.TEXT_MUTED2 if is_done else T.TEXT_PRIMARY
        title_font = ("Segoe UI", 9, "overstrike") if is_done else ("Segoe UI", 10)
        tk.Label(info, text=task.title, font=title_font,
                 bg=T.BG_SURFACE2, fg=title_fg, anchor="w").pack(anchor="w")

        # Meta: hora, descripción, badge
        meta_parts: List[str] = []
        if task.start_time:
            end = task.end_time.strftime("%H:%M") if task.end_time else "?"
            meta_parts.append(
                f"🕐 {task.start_time.strftime('%H:%M')} – {end}")
        if task.is_carried_over:
            meta_parts.append("↩ postergada")
        if task.description:
            desc = task.description[:50] + (
                "…" if len(task.description) > 50 else "")
            meta_parts.insert(0, desc)
        if meta_parts:
            tk.Label(info, text="   ".join(meta_parts),
                     font=("Segoe UI", 7), bg=T.BG_SURFACE2,
                     fg=T.TEXT_MUTED2, anchor="w").pack(anchor="w")

        # Botones de acción
        btn_frame = tk.Frame(card, bg=T.BG_SURFACE2)
        btn_frame.pack(side="right", padx=(0, 6))

        if task.status == TaskStatus.PENDING:
            self._chip(btn_frame, "▶ Iniciar", T.ACCENT_BLUE,
                       lambda t=task: self._do_start(t))
        elif task.status == TaskStatus.IN_PROGRESS:
            self._chip(btn_frame, "✓ Listo", T.ACCENT_GREEN,
                       lambda t=task: self._do_complete(t))
            self._chip(btn_frame, "⏸ Pausar", T.TEXT_MUTED2,
                       lambda t=task: self._do_pend(t))
        else:
            self._chip(btn_frame, "↩", T.TEXT_MUTED2,
                       lambda t=task: self._do_pend(t))

        del_btn = tk.Label(card, text="✕", font=("Segoe UI", 11),
                           bg=T.BG_SURFACE2, fg=T.TEXT_MUTED,
                           cursor="hand2", padx=8)
        del_btn.pack(side="right", anchor="center")
        del_btn.bind("<Button-1>",
                     lambda e, t=task: self._remove_task(t))
        del_btn.bind("<Enter>",
                     lambda e: e.widget.config(fg=T.ACCENT_RED))
        del_btn.bind("<Leave>",
                     lambda e: e.widget.config(fg=T.TEXT_MUTED))

        # Hover
        for w in [card, info]:
            w.bind("<Enter>",
                   lambda e, c=card, ch=chk, i=info:
                   self._hover(c, [ch, i], True))
            w.bind("<Leave>",
                   lambda e, c=card, ch=chk, i=info:
                   self._hover(c, [ch, i], False))

    def _chip(self, parent: tk.Frame, text: str, color: str,
              cmd) -> None:
        btn = tk.Label(parent, text=text, font=("Segoe UI", 7, "bold"),
                       bg=T.BG_SURFACE2, fg=color, cursor="hand2",
                       padx=6, pady=3)
        btn.pack(side="left", padx=2, pady=6)
        btn.bind("<Button-1>", lambda e: cmd())
        btn.bind("<Enter>", lambda e: btn.config(bg=T.BORDER))
        btn.bind("<Leave>", lambda e: btn.config(bg=T.BG_SURFACE2))

    def _hover(self, card: tk.Frame, extras: list, entering: bool) -> None:
        bg = T.BORDER if entering else T.BG_SURFACE2
        try:
            card.config(bg=bg)
            for w in extras:
                w.config(bg=bg)
        except tk.TclError:
            pass

    def _empty_state(self, parent: tk.Frame, title: str, sub: str) -> None:
        f = tk.Frame(parent, bg=T.BG_BASE)
        f.pack(fill="x", padx=8, pady=24)
        tk.Label(f, text=title, font=("Segoe UI", 10, "bold"),
                 bg=T.BG_BASE, fg=T.TEXT_MUTED2).pack()
        tk.Label(f, text=sub, font=("Segoe UI", 8),
                 bg=T.BG_BASE, fg=T.TEXT_MUTED).pack(pady=(4, 0))

    # ══════════════════════════════════════════════════════════════════════════
    # TASK ACTIONS
    # ══════════════════════════════════════════════════════════════════════════
    def _do_start(self, task: Task) -> None:
        updated = Task.from_dict(
            {**task.to_dict(), "status": int(TaskStatus.IN_PROGRESS)})
        self._repo.save_task(updated)
        self._schedule_refresh(immediate=True)

    def _do_complete(self, task: Task) -> None:
        updated = Task.from_dict(
            {**task.to_dict(), "status": int(TaskStatus.COMPLETED)})
        self._repo.save_task(updated)
        # Focus blocks
        blocks = cfg.increment_completed_blocks()
        needed = cfg.get_blocks_to_unlock()
        if blocks % needed == 0:
            dur = cfg.get_unlock_duration()
            now = datetime.now()
            session = BlockSession(
                unlocked_at=now,
                expires_at=now + timedelta(minutes=dur))
            self._repo.save_session(session)
            threading.Thread(
                target=_notify,
                args=("FocusGuard",
                      f"¡{needed} bloques completados!  {dur} min libres."),
                daemon=True).start()
        self._schedule_refresh(immediate=True)

    def _do_pend(self, task: Task) -> None:
        updated = Task.from_dict(
            {**task.to_dict(), "status": int(TaskStatus.PENDING)})
        self._repo.save_task(updated)
        self._schedule_refresh(immediate=True)

    def _remove_task(self, task: Task) -> None:
        if messagebox.askyesno("Eliminar tarea",
                               f"¿Eliminar '{task.title}'?",
                               parent=self.root):
            self._repo.delete_task(task.id)
            self._schedule_refresh(immediate=True)

    def _home_add_task(self) -> None:
        text = self._home_entry.get().strip()
        ph = "Añadir tarea para hoy…"
        if text and text != ph:
            today = datetime.now().replace(
                hour=0, minute=0, second=0, microsecond=0)
            existing = self._repo.get_tasks_for_date(today)
            self._repo.save_task(
                Task(title=text, date=today, day_order=len(existing)))
            self._home_entry.delete(0, "end")
            self._schedule_refresh(immediate=True)

    def _cal_add_task(self) -> None:
        text = self._cal_entry.get().strip()
        ph = "Añadir tarea para este día…"
        if text and text != ph:
            existing = self._repo.get_tasks_for_date(self._cal_date)
            self._repo.save_task(
                Task(title=text, date=self._cal_date,
                     day_order=len(existing)))
            self._cal_entry.delete(0, "end")
            self._schedule_refresh(immediate=True)

    def _add_app(self) -> None:
        exe = self._app_entry.get().strip()
        if exe and exe != self._APP_PH:
            cfg.add_blocked_app(exe)
            self._app_entry.delete(0, "end")
            self._app_fo(None)
            self._render_sett_apps()

    def _remove_app(self, exe: str) -> None:
        if messagebox.askyesno("Eliminar app",
                               f"¿Dejar de bloquear '{exe}'?",
                               parent=self.root):
            cfg.remove_blocked_app(exe)
            self._render_sett_apps()

    def _app_fi(self, _) -> None:
        if self._app_entry.get() == self._APP_PH:
            self._app_entry.delete(0, "end")
            self._app_entry.config(fg=T.TEXT_PRIMARY)

    def _app_fo(self, _) -> None:
        if not self._app_entry.get():
            self._app_entry.insert(0, self._APP_PH)
            self._app_entry.config(fg=T.TEXT_MUTED)

    def _set_unlock_hour(self) -> None:
        if self._setting_hour:
            return
        try:
            cfg.set_unlock_hour(int(self._hour_var.get()))
        except (ValueError, tk.TclError):
            pass

    def _toggle_pause(self) -> None:
        if self.blocker.is_paused():
            self.blocker.resume()
        else:
            self.blocker.pause(15)
        self._schedule_refresh(immediate=True)

    def _toggle_theme(self) -> None:
        name = self._theme_var.get()
        if name == "dark":
            apply_dark()
            cfg.set_dark_mode(True)
        else:
            apply_light()
            cfg.set_dark_mode(False)
        # Cancelar refresh pendiente para evitar re-entradas
        if self._after_id:
            try:
                self.root.after_cancel(self._after_id)
            except Exception:
                pass
            self._after_id = None
        self.status_bar.refresh_theme()
        self._build()
        self._refresh()

    def _on_close(self) -> None:
        if messagebox.askyesno(
            "FocusGuard",
            "¿Minimizar a la bandeja del sistema?\n\n"
            "(Cerrar completamente desactiva la protección)",
            parent=self.root,
        ):
            self.root.withdraw()

    # ══════════════════════════════════════════════════════════════════════════
    # LAYOUT helpers
    # ══════════════════════════════════════════════════════════════════════════
    def _section_header(self, parent: tk.Frame, label: str,
                        right_var: str = "") -> None:
        f = tk.Frame(parent, bg=T.BG_BASE)
        f.pack(fill="x", padx=16, pady=(14, 4))
        tk.Label(f, text=label, font=("Segoe UI", 9, "bold"),
                 bg=T.BG_BASE, fg=T.TEXT_PRIMARY).pack(side="left")
        if right_var:
            lbl = tk.Label(f, text="", font=("Segoe UI", 8),
                           bg=T.BG_BASE, fg=T.ACCENT_BLUE)
            lbl.pack(side="right")
            setattr(self, right_var, lbl)
        tk.Frame(parent, bg=T.SEPARATOR, height=1).pack(
            fill="x", padx=16, pady=(0, 2))

    def _make_scrollable(self, parent: tk.Frame) -> tuple:
        container = tk.Frame(parent, bg=T.BG_BASE)
        container.pack(fill="both", expand=True)
        canvas = tk.Canvas(container, bg=T.BG_BASE, bd=0,
                           highlightthickness=0)
        sb = tk.Scrollbar(container, orient="vertical",
                          command=canvas.yview,
                          bg=T.BG_SURFACE2, troughcolor=T.BG_BASE,
                          activebackground=T.BORDER_FOCUS,
                          width=5, relief="flat", bd=0,
                          highlightthickness=0)
        inner = tk.Frame(canvas, bg=T.BG_BASE)
        win_id = canvas.create_window((0, 0), window=inner, anchor="nw")
        inner.bind("<Configure>",
                   lambda _: canvas.configure(
                       scrollregion=canvas.bbox("all")))
        canvas.bind("<Configure>",
                    lambda e: canvas.itemconfig(win_id, width=e.width))
        canvas.configure(yscrollcommand=sb.set)
        sb.pack(side="right", fill="y")
        canvas.pack(side="left", fill="both", expand=True)
        return inner, canvas

    def _make_entry(self, parent: tk.Frame,
                    placeholder: str = "") -> tuple:
        wrapper = tk.Frame(parent, bg=T.BORDER)
        entry = tk.Entry(wrapper, font=("Segoe UI", 10),
                         bg=T.BG_INPUT, fg=T.TEXT_PRIMARY,
                         insertbackground=T.ACCENT_BLUE,
                         relief="flat", bd=0, highlightthickness=0)
        entry.pack(fill="x", expand=True, padx=1, pady=1, ipady=6)
        if placeholder:
            entry.insert(0, placeholder)
            entry.config(fg=T.TEXT_MUTED)
            entry.bind("<FocusIn>", lambda e, ph=placeholder:
                       self._ph_in(entry, ph))
            entry.bind("<FocusOut>", lambda e, ph=placeholder:
                       self._ph_out(entry, ph))
        entry.bind("<FocusIn>",
                   lambda e, _orig=entry.bind("<FocusIn>"):
                   wrapper.config(bg=T.BORDER_FOCUS),
                   add="+")
        entry.bind("<FocusOut>",
                   lambda e: wrapper.config(bg=T.BORDER),
                   add="+")
        return wrapper, entry

    @staticmethod
    def _ph_in(entry: tk.Entry, ph: str) -> None:
        if entry.get() == ph:
            entry.delete(0, "end")
            entry.config(fg=T.TEXT_PRIMARY)

    @staticmethod
    def _ph_out(entry: tk.Entry, ph: str) -> None:
        if not entry.get():
            entry.insert(0, ph)
            entry.config(fg=T.TEXT_MUTED)

    def _make_add_btn(self, parent: tk.Frame, command) -> tk.Frame:
        wrapper = tk.Frame(parent, bg=T.ACCENT_BLUE)
        btn = tk.Button(wrapper, text="+",
                        font=("Segoe UI", 14, "bold"),
                        bg=T.BG_SURFACE2, fg=T.ACCENT_BLUE,
                        relief="flat", bd=0, cursor="hand2",
                        width=3, pady=2, command=command)
        btn.pack(padx=1, pady=1)
        btn.bind("<Enter>", lambda _: btn.config(bg=T.BORDER))
        btn.bind("<Leave>", lambda _: btn.config(bg=T.BG_SURFACE2))
        return wrapper

    def _link_btn(self, parent: tk.Frame, text: str,
                  command, side: str = "left") -> tk.Label:
        btn = tk.Label(parent, text=text,
                       font=("Segoe UI", 9, "bold"),
                       bg=T.BG_BASE, fg=T.ACCENT_BLUE,
                       cursor="hand2")
        btn.bind("<Button-1>", lambda e: command())
        btn.bind("<Enter>",
                 lambda e: btn.config(fg=T.TEXT_PRIMARY))
        btn.bind("<Leave>",
                 lambda e: btn.config(fg=T.ACCENT_BLUE))
        return btn

    @staticmethod
    def _bind_mw(widget: tk.Widget, handler) -> None:
        widget.bind("<MouseWheel>", handler)
        for child in widget.winfo_children():
            MainWindow._bind_mw(child, handler)

    # ══════════════════════════════════════════════════════════════════════════
    # REFRESH CYCLE
    # ══════════════════════════════════════════════════════════════════════════
    def _handle_unlock_transition(self) -> None:
        data   = cfg.get_data()
        now    = datetime.now(MEXICO_TZ)
        reason = ("hora" if now.hour >= data.get("unlock_hour", 21)
                  else "tareas")
        msg    = (f"Desbloqueado · {now.hour:02d}:{now.minute:02d}"
                  if reason == "hora"
                  else "Desbloqueado · Todas las tareas completadas.")
        if not self._history_saved:
            cfg.save_history(reason)
            self._history_saved = True
        threading.Thread(target=_notify, args=("FocusGuard", msg),
                         daemon=True).start()

    def _schedule_refresh(self, immediate: bool = False) -> None:
        if self._after_id is not None:
            try:
                self.root.after_cancel(self._after_id)
            except Exception:
                pass
            self._after_id = None
        delay = (0 if immediate
                 else 1000 if self.blocker.is_paused()
                 else 5000)
        self._after_id = self.root.after(delay, self._refresh)

    def _refresh(self) -> None:
        self._after_id = None
        try:
            self._do_refresh()
        except Exception as e:
            log.error(f"Error en refresh: {e}", exc_info=True)
        self._schedule_refresh()

    def _do_refresh(self) -> None:
        cfg.check_daily_reset()

        data        = cfg.get_data()
        blocking    = cfg.is_blocking_active()
        paused      = self.blocker.is_paused()
        now         = datetime.now(MEXICO_TZ)
        today_tasks = self._repo.get_tasks_for_date(datetime.now())
        done        = sum(1 for t in today_tasks
                         if t.status == TaskStatus.COMPLETED)
        total       = len(today_tasks)

        # Transición bloqueando → libre
        if self._was_blocking and not blocking:
            self._handle_unlock_transition()
        if blocking:
            self._history_saved = False
        self._was_blocking = blocking

        # — Reloj —
        self._clock_lbl.config(text=now.strftime("%H:%M"))

        # — Dot —
        self._dot.set_state(blocking, paused)

        unlock_h = data.get("unlock_hour", 21)

        # — Status —
        if paused:
            rem = int(self.blocker.pause_remaining_seconds())
            mm, ss = divmod(rem, 60)
            self._status_lbl.config(
                text=f"Pausado  {mm:02d}:{ss:02d}", fg=T.ACCENT_GOLD)
            self._status_desc.config(
                text="El bloqueador está pausado temporalmente",
                fg=T.TEXT_MUTED2)
            self._pause_btn.config(text="Reanudar ahora")
            self._status_pill.config(text="⏸ PAUSA", fg=T.ACCENT_GOLD)
            bar_color = T.ACCENT_GOLD
        elif blocking:
            self._status_lbl.config(text="Bloqueando", fg=T.ACCENT_RED)
            self._status_desc.config(
                text=f"Apps bloqueadas hasta las {unlock_h:02d}:00 "
                     "o al completar todas las tareas",
                fg=T.TEXT_MUTED2)
            self._pause_btn.config(text="Pausar 15 min")
            self._status_pill.config(text="🔒 ACTIVO", fg=T.ACCENT_RED)
            bar_color = T.ACCENT_RED
        else:
            self._status_lbl.config(text="Libre", fg=T.ACCENT_GREEN)
            self._status_desc.config(
                text="Sin restricciones activas",
                fg=T.TEXT_MUTED2)
            self._pause_btn.config(text="Pausar 15 min")
            self._status_pill.config(text="🔓 LIBRE", fg=T.ACCENT_GREEN)
            bar_color = T.ACCENT_GREEN

        # — Barra de progreso global —
        self._bar.set_progress(
            done / total if total else 0.0,
            bar_color if paused else "")

        # — Contador + racha —
        if total:
            self._count_lbl.config(text=f"{done} de {total} tarea{'s' if total != 1 else ''}")
        else:
            self._count_lbl.config(
                text=f"Sin tareas · libre a las {unlock_h:02d}:00")
        streak = cfg.get_streak()
        self._streak_lbl.config(
            text=f"🔥 Racha: {streak} día{'s' if streak != 1 else ''}"
            if streak > 0 else "")

        # — Sync spinbox —
        self._setting_hour = True
        self._hour_var.set(unlock_h)
        self._setting_hour = False

        # — HOME tab —
        self._home_done_lbl.config(text=str(done))
        self._home_total_lbl.config(
            text=f" / {total} tarea{'s' if total != 1 else ''}")
        pct = int(done / total * 100) if total else 0
        self._home_pct_lbl.config(text=f"{pct}%" if total else "")
        self._home_bar.set_progress(done / total if total else 0.0, "")
        if hasattr(self, "_today_badge"):
            self._today_badge.config(
                text=f"{total} tarea{'s' if total != 1 else ''}")

        # Focus blocks dots
        blocks_today = cfg.get_completed_blocks_today()
        needed       = cfg.get_blocks_to_unlock()
        in_cycle     = blocks_today % needed if blocks_today else 0

        for w in self._dots_frame.winfo_children():
            w.destroy()
        for i in range(needed):
            filled = i < in_cycle
            dot = tk.Label(self._dots_frame,
                           text="●" if filled else "○",
                           font=("Segoe UI", 11),
                           bg=T.BG_SURFACE2,
                           fg=T.ACCENT_BLUE if filled else T.TEXT_MUTED)
            dot.pack(side="left", padx=2)

        session = self._repo.get_active_session()
        if session and not session.is_expired:
            mm, ss = divmod(session.remaining_seconds, 60)
            self._session_badge.config(
                text=f"🔓 {mm}:{ss:02d} libres", fg=T.ACCENT_GREEN)
            self._blocks_lbl.config(text="Sesión activa", fg=T.ACCENT_GREEN)
        else:
            self._session_badge.config(text="")
            left = needed - in_cycle
            self._blocks_lbl.config(
                text=f"{left} más para desbloquear",
                fg=T.TEXT_MUTED2)

        self._render_home_tasks(today_tasks)

        # — CALENDARIO tab (solo si está visible) —
        try:
            if self._nb.index("current") == 1:
                self._render_cal_tasks()
        except Exception:
            pass

        self.status_bar.update_status(blocking, paused)
