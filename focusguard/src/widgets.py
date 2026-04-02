"""
Sistema de temas (dark / light) y widgets visuales reutilizables.

Todos los módulos de UI usan T.BG_BASE, T.ACCENT_GREEN, etc.
Al cambiar de tema: apply_dark() / apply_light() → reconstruir UI.
"""
from __future__ import annotations

import math
import tkinter as tk

# ── Paletas ────────────────────────────────────────────────────────────────────

_DARK: dict[str, str] = dict(
    # Fondos
    BG_BASE      = "#0d0d0d",
    BG_SURFACE   = "#111111",
    BG_SURFACE2  = "#1a1a1a",
    BG_INPUT     = "#1a1a1a",
    # Bordes
    BORDER       = "#2a2a2a",
    BORDER_FOCUS = "#0a84ff",
    SEPARATOR    = "#222222",
    # Texto
    TEXT_PRIMARY = "#ffffff",
    TEXT_MUTED   = "#555555",
    TEXT_MUTED2  = "#888888",
    # Acentos funcionales
    ACCENT_WHITE = "#ffffff",
    ACCENT_BLUE  = "#0a84ff",
    ACCENT_RED   = "#ff453a",
    ACCENT_GREEN = "#30d158",
    ACCENT_GOLD  = "#ff9f0a",
    # Alias compatibilidad
    C_BG         = "#0d0d0d",
    C_CARD       = "#1a1a1a",
    C_BORDER     = "#2a2a2a",
    C_TEXT       = "#ffffff",
    C_DIM        = "#555555",
    C_BLOCK      = "#ff453a",
    C_ALLOW      = "#30d158",
    C_BTN        = "#1a1a1a",
    C_PAUSE      = "#ff9f0a",
    # Dim para punto pulsante
    _RED_DIM     = "#3d1110",
    _GREEN_DIM   = "#0d3318",
    _BLUE_DIM    = "#031a33",
    _GOLD_DIM    = "#3d2700",
)

_LIGHT: dict[str, str] = dict(
    BG_BASE      = "#f2f2f7",
    BG_SURFACE   = "#ffffff",
    BG_SURFACE2  = "#ffffff",
    BG_INPUT     = "#ffffff",
    BORDER       = "#d1d1d6",
    BORDER_FOCUS = "#007aff",
    SEPARATOR    = "#e5e5ea",
    TEXT_PRIMARY = "#1c1c1e",
    TEXT_MUTED   = "#aeaeb2",
    TEXT_MUTED2  = "#6c6c70",
    ACCENT_WHITE = "#1c1c1e",
    ACCENT_BLUE  = "#007aff",
    ACCENT_RED   = "#ff3b30",
    ACCENT_GREEN = "#34c759",
    ACCENT_GOLD  = "#ff9500",
    C_BG         = "#f2f2f7",
    C_CARD       = "#ffffff",
    C_BORDER     = "#d1d1d6",
    C_TEXT       = "#1c1c1e",
    C_DIM        = "#aeaeb2",
    C_BLOCK      = "#ff3b30",
    C_ALLOW      = "#34c759",
    C_BTN        = "#ffffff",
    C_PAUSE      = "#ff9500",
    _RED_DIM     = "#ffe5e3",
    _GREEN_DIM   = "#d4f4dc",
    _BLUE_DIM    = "#d0e8ff",
    _GOLD_DIM    = "#ffecd0",
)


# ── Objeto de tema activo ──────────────────────────────────────────────────────

class _Theme:
    """Namespace mutable: acceso como T.BG_BASE, T.ACCENT_GREEN, etc."""
    def apply(self, palette: dict[str, str]) -> None:
        self.__dict__.update(palette)

T = _Theme()
T.apply(_DARK)          # default: dark


def apply_dark() -> None:
    T.apply(_DARK)

def apply_light() -> None:
    T.apply(_LIGHT)

def is_dark() -> bool:
    return T.BG_BASE == _DARK["BG_BASE"]

def current_name() -> str:
    return "dark" if is_dark() else "light"


# ── Backward-compat: variables de módulo (para imports existentes) ─────────────
# Se actualizan al llamar apply_dark/apply_light si el módulo se reimporta,
# pero el uso recomendado es T.xxx.
BG_BASE      = _DARK["BG_BASE"]
BG_SURFACE   = _DARK["BG_SURFACE"]
BG_SURFACE2  = _DARK["BG_SURFACE2"]
BG_INPUT     = _DARK["BG_INPUT"]
BORDER       = _DARK["BORDER"]
BORDER_FOCUS = _DARK["BORDER_FOCUS"]
SEPARATOR    = _DARK["SEPARATOR"]
TEXT_PRIMARY = _DARK["TEXT_PRIMARY"]
TEXT_MUTED   = _DARK["TEXT_MUTED"]
TEXT_MUTED2  = _DARK["TEXT_MUTED2"]
ACCENT_WHITE = _DARK["ACCENT_WHITE"]
ACCENT_RED   = _DARK["ACCENT_RED"]
ACCENT_GREEN = _DARK["ACCENT_GREEN"]
ACCENT_GOLD  = _DARK["ACCENT_GOLD"]
C_BG         = _DARK["C_BG"]
C_CARD       = _DARK["C_CARD"]
C_BORDER     = _DARK["C_BORDER"]
C_TEXT       = _DARK["C_TEXT"]
C_DIM        = _DARK["C_DIM"]
C_BLOCK      = _DARK["C_BLOCK"]
C_ALLOW      = _DARK["C_ALLOW"]
C_BTN        = _DARK["C_BTN"]
C_PAUSE      = _DARK["C_PAUSE"]


# ── Helpers ────────────────────────────────────────────────────────────────────

def lerp_color(c1: str, c2: str, t: float) -> str:
    t = max(0.0, min(1.0, t))
    r1, g1, b1 = int(c1[1:3], 16), int(c1[3:5], 16), int(c1[5:7], 16)
    r2, g2, b2 = int(c2[1:3], 16), int(c2[3:5], 16), int(c2[5:7], 16)
    return "#{:02x}{:02x}{:02x}".format(
        int(r1 + (r2 - r1) * t),
        int(g1 + (g2 - g1) * t),
        int(b1 + (b2 - b1) * t),
    )


def spaced(text: str, sep: str = "  ") -> str:
    """Simula letter-spacing insertando separador entre caracteres."""
    return sep.join(text)


# ── Widgets ────────────────────────────────────────────────────────────────────

class PulsingDot(tk.Canvas):
    """Círculo de 8px que pulsa entre dim y bright según estado."""
    SIZE = 8

    def __init__(self, parent: tk.Widget, **kwargs):
        bg = kwargs.pop("bg", T.BG_BASE)
        super().__init__(parent, width=self.SIZE, height=self.SIZE,
                         bg=bg, bd=0, highlightthickness=0, **kwargs)
        self._phase        = 0.0
        self._color_bright = T.ACCENT_GREEN
        self._color_dim    = T._GREEN_DIM
        self._dot = self.create_oval(0, 0, self.SIZE, self.SIZE,
                                     fill=self._color_bright, outline="")
        self._tick()

    def set_state(self, blocking: bool, paused: bool = False) -> None:
        if paused:
            self._color_bright = T.ACCENT_GOLD
            self._color_dim    = T._GOLD_DIM
        elif blocking:
            self._color_bright = T.ACCENT_RED
            self._color_dim    = T._RED_DIM
        else:
            self._color_bright = T.ACCENT_GREEN
            self._color_dim    = T._GREEN_DIM

    def _tick(self) -> None:
        t = 0.3 + 0.7 * (math.sin(self._phase) + 1) / 2
        try:
            self.itemconfig(self._dot,
                            fill=lerp_color(self._color_dim, self._color_bright, t))
            self._phase += 0.0838
            self.after(16, self._tick)
        except tk.TclError:
            pass  # widget destruido al cambiar tema


class AnimatedBar(tk.Canvas):
    """Barra de progreso animada."""

    def __init__(self, parent: tk.Widget, height: int = 4, **kwargs):
        kwargs.setdefault("bg", T.SEPARATOR)
        super().__init__(parent, height=height, bd=0, highlightthickness=0, **kwargs)
        self._progress = 0.0
        self._target   = 0.0
        self._color    = T.ACCENT_RED
        self.bind("<Configure>", lambda _e: self._draw())

    def set_progress(self, fraction: float, color: str = "") -> None:
        self._target = max(0.0, min(1.0, fraction))
        if color:
            self._color = color
        elif self._target >= 1.0:
            self._color = T.ACCENT_GREEN
        elif self._target >= 0.5:
            self._color = T.ACCENT_GOLD
        else:
            self._color = T.ACCENT_RED
        self._animate()

    def _animate(self) -> None:
        diff = self._target - self._progress
        if abs(diff) > 0.004:
            self._progress += diff * 0.18
            self._draw()
            try:
                self.after(16, self._animate)
            except tk.TclError:
                pass
        else:
            self._progress = self._target
            self._draw()

    def _draw(self) -> None:
        w, h = self.winfo_width(), self.winfo_height()
        if w < 2 or h < 2:
            return
        self.delete("all")
        self.create_rectangle(0, 0, w, h, fill=T.SEPARATOR, outline="")
        fw = int(w * self._progress)
        if fw > 0:
            self.create_rectangle(0, 0, fw, h, fill=self._color, outline="")


class CheckBox(tk.Canvas):
    """Checkbox cuadrado de 14px dibujado con Canvas."""
    SIZE = 14

    def __init__(self, parent: tk.Widget, checked: bool = False,
                 bg: str | None = None, **kwargs):
        bg = bg or T.BG_SURFACE2
        super().__init__(parent, width=self.SIZE, height=self.SIZE,
                         bg=bg, bd=0, highlightthickness=0, **kwargs)
        self._checked = checked
        self._draw()

    def set_checked(self, value: bool) -> None:
        if self._checked != value:
            self._checked = value
            self._draw()

    def set_bg(self, color: str) -> None:
        self.config(bg=color)

    def _draw(self) -> None:
        s = self.SIZE
        self.delete("all")
        if self._checked:
            self.create_rectangle(2, 2, s - 3, s - 3, fill=T.ACCENT_GREEN, outline="")
            self.create_line(4, 7, 6, 10,  fill=T.BG_BASE, width=2)
            self.create_line(6, 10, 11, 5, fill=T.BG_BASE, width=2)
        else:
            self.create_rectangle(2, 2, s - 3, s - 3,
                                  fill=T.BG_INPUT, outline=T.BORDER_FOCUS)
