"""
System tray icon for FocusGuard (Windows).

Dependencies: pystray, Pillow. If they are missing, callers should catch ImportError.
"""
from __future__ import annotations

import threading
from io import BytesIO
from typing import Callable
from base64 import b64decode

from PIL import Image
import pystray


# 16x16 ICO-like PNG (simple dark circle with FG letters)
_ICON_BASE64 = (
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAS0lEQVR4nGNgGGjAiFPmRMV/"
    "FL5FB1a1jAQ1ogM0g5hI0oxFDRMDhYCJJNuxqGWingsG3gAL7PGMFSCpZaKeCxiIdAWaGoq"
    "T8sADAGHFFRZsmSd2AAAAAElFTkSuQmCC"
)


def _icon_image() -> Image.Image:
    data = b64decode(_ICON_BASE64)
    return Image.open(BytesIO(data))


class SystemTray:
    """Light wrapper around pystray.Icon running in a daemon thread."""

    def __init__(self, on_open: Callable[[], None], on_exit: Callable[[], None]):
        self._on_open = on_open
        self._on_exit = on_exit
        self._icon = pystray.Icon(
            "FocusGuard",
            icon=_icon_image(),
            title="FocusGuard",
            menu=pystray.Menu(
                pystray.MenuItem("Abrir", lambda: self._safe(self._on_open)),
                pystray.MenuItem("Salir", lambda: self._safe(self._on_exit)),
            ),
        )
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._thread = threading.Thread(target=self._icon.run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        try:
            self._icon.stop()
        except Exception:
            pass

    def _safe(self, fn: Callable[[], None]) -> None:
        try:
            fn()
        except Exception:
            # tray callbacks must not raise
            pass
