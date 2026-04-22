"""
BlockerThread: hilo daemon que mata procesos bloqueados cada N segundos.

Comparte el RLock de config.py para evitar race conditions con la UI.
Soporta pausa temporal con countdown.
"""
from __future__ import annotations

import logging
import threading
from datetime import datetime, timedelta

import psutil

from . import config as cfg

log = logging.getLogger("focusguard.blocker")


class BlockerThread(threading.Thread):

    def __init__(self, interval: int = 3):
        super().__init__(daemon=True, name="BlockerThread")
        self._interval   = interval
        self._stop_evt   = threading.Event()
        self._pause_lock = threading.Lock()
        self._pause_until: datetime | None = None

    # ── Pausa ─────────────────────────────────────────────────────────────────
    def pause(self, minutes: int = 15) -> None:
        with self._pause_lock:
            self._pause_until = datetime.now() + timedelta(minutes=minutes)
        log.info(f"Bloqueador pausado por {minutes} minutos.")

    def resume(self) -> None:
        with self._pause_lock:
            self._pause_until = None
        log.info("Bloqueador reanudado.")

    def is_paused(self) -> bool:
        with self._pause_lock:
            if self._pause_until is None:
                return False
            if datetime.now() >= self._pause_until:
                self._pause_until = None
                log.info("Pausa expirada, bloqueador reanudado automaticamente.")
                return False
            return True

    def pause_remaining_seconds(self) -> float:
        """Segundos restantes de pausa, o 0.0 si no esta pausado."""
        with self._pause_lock:
            if self._pause_until is None:
                return 0.0
            return max(0.0, (self._pause_until - datetime.now()).total_seconds())

    # ── Ciclo principal ────────────────────────────────────────────────────────
    def run(self) -> None:
        log.info("BlockerThread iniciado.")
        while not self._stop_evt.wait(self._interval):
            try:
                if self.is_paused():
                    continue

                with cfg.get_lock():
                    active  = cfg.is_blocking_active()
                    blocked = {b.lower() for b in cfg.get_data().get("blocked_apps", [])}

                if not active or not blocked:
                    continue

                for proc in psutil.process_iter(["name", "pid"]):
                    try:
                        name = (proc.info.get("name") or "").lower()
                        if name in blocked:
                            proc.kill()
                            log.warning(
                                f"Proceso terminado: {proc.info['name']} "
                                f"(pid={proc.info['pid']})"
                            )
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass

            except Exception as exc:
                log.error(f"Error en BlockerThread: {exc}", exc_info=True)

        log.info("BlockerThread detenido.")

    def stop(self) -> None:
        self._stop_evt.set()
