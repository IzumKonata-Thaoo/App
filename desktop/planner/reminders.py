"""Bộ máy nhắc nhở: sự kiện sắp tới, nhắc hằng ngày, nhắc theo chu kỳ giờ."""
from __future__ import annotations

import math
import struct
import wave
from datetime import datetime, timedelta

from PySide6.QtCore import QTimer, QUrl, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtWidgets import QApplication, QFrame, QHBoxLayout, QLabel, QPushButton, QSystemTrayIcon, QVBoxLayout

from .data import Store, data_dir, hhmm_to_min

try:
    from PySide6.QtMultimedia import QSoundEffect
except Exception:  # pragma: no cover - QtMultimedia có thể thiếu
    QSoundEffect = None


def _make_chime(path):
    rate, notes = 22050, [(1046.5, 0.0), (1318.5, 0.18), (1568.0, 0.36)]
    total = int(rate * 1.4)
    samples = [0.0] * total
    for freq, off in notes:
        for i in range(int((total / rate - off) * rate)):
            t = i / rate
            idx = i + int(off * rate)
            samples[idx] += math.sin(2 * math.pi * freq * t) * math.exp(-t * 4.5) * 0.28
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


class Toast(QFrame):
    """Thẻ nhắc nhở nổi ở góc màn hình."""

    def __init__(self, manager, title: str, body: str, snooze_cb):
        super().__init__(None, Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
        self.manager = manager
        self.setObjectName("toast")
        self.setAttribute(Qt.WA_ShowWithoutActivating)
        self.setAttribute(Qt.WA_DeleteOnClose)
        self.setFixedWidth(340)

        t = QLabel("🔔  " + title)
        t.setObjectName("h3")
        t.setWordWrap(True)
        b = QLabel(body)
        b.setWordWrap(True)
        ok = QPushButton("Đã biết 💕")
        ok.setObjectName("primary")
        ok.clicked.connect(self.close)
        snooze = QPushButton("Nhắc lại sau 5 phút")
        snooze.clicked.connect(lambda: (snooze_cb(), self.close()))
        row = QHBoxLayout()
        row.addWidget(snooze)
        row.addWidget(ok)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(18, 16, 18, 14)
        lay.setSpacing(8)
        lay.addWidget(t)
        lay.addWidget(b)
        lay.addLayout(row)
        QTimer.singleShot(30_000, self.close)

    def closeEvent(self, e):
        self.manager.remove(self)
        super().closeEvent(e)


class ReminderEngine:
    def __init__(self, store: Store, tray: QSystemTrayIcon | None = None):
        self.store = store
        self.tray = tray
        self.toasts: list[Toast] = []
        self.sound = None
        if QSoundEffect is not None:
            try:
                wav = data_dir() / "chime.wav"
                if not wav.exists():
                    _make_chime(wav)
                self.sound = QSoundEffect()
                self.sound.setSource(QUrl.fromLocalFile(str(wav)))
                self.sound.setVolume(0.7)
            except Exception:
                self.sound = None
        self.timer = QTimer()
        self.timer.timeout.connect(self.tick)
        self.timer.start(15_000)
        QTimer.singleShot(1500, self.tick)

    # ---- hiển thị ----------------------------------------------------
    def notify(self, title: str, body: str, snooze: bool = True):
        if self.store.settings.get("sound_on"):
            if self.sound is not None:
                self.sound.play()
            else:
                QApplication.beep()
        toast = Toast(self, title, body, lambda: self.snooze(title, body, 5))
        self.toasts.append(toast)
        toast.show()
        self._layout()
        if self.tray is not None and self.tray.isVisible():
            self.tray.showMessage(title, body, QSystemTrayIcon.Information, 8000)

    def snooze(self, title: str, body: str, minutes: int):
        QTimer.singleShot(minutes * 60_000, lambda: self.notify(title, body))

    def remove(self, toast: Toast):
        if toast in self.toasts:
            self.toasts.remove(toast)
        self._layout()

    def _layout(self):
        screen = QGuiApplication.primaryScreen().availableGeometry()
        y = screen.bottom() - 16
        for t in reversed(self.toasts):
            t.adjustSize()
            y -= t.height()
            t.move(screen.right() - t.width() - 16, y)
            y -= 10

    # ---- kiểm tra định kỳ ---------------------------------------------
    def tick(self, now: datetime | None = None):
        now = now or datetime.now()
        self._check_events(now)
        self._check_daily(now)
        self._check_interval(now)

    def _check_events(self, now: datetime):
        for offset in (0, 1):
            day = (now + timedelta(days=offset)).date()
            for ev in self.store.events_on(day):
                if ev.remind is None:
                    continue
                key = f"ev:{ev.id}:{day.isoformat()}"
                if self.store.was_fired(key):
                    continue
                start_min = hhmm_to_min(ev.start) if ev.start else 8 * 60  # cả ngày: nhắc 08:00
                start_dt = datetime.combine(day, datetime.min.time()) + timedelta(minutes=start_min)
                fire_dt = start_dt - timedelta(minutes=ev.remind)
                if fire_dt <= now < start_dt + timedelta(minutes=30):
                    self.store.mark_fired(key)
                    when = f"lúc {ev.start}" if ev.start else "cả ngày"
                    lead = "ngay bây giờ" if ev.remind == 0 else f"sau {self._fmt_lead(ev.remind)}"
                    body = f"{ev.title} ({when}, {day.strftime('%d/%m')}) – {lead}"
                    if ev.note:
                        body += f"\n📝 {ev.note}"
                    self.notify("Sắp đến giờ rồi!", body)

    @staticmethod
    def _fmt_lead(m: int) -> str:
        if m % 1440 == 0:
            return f"{m // 1440} ngày"
        if m % 60 == 0:
            return f"{m // 60} giờ"
        return f"{m} phút"

    def _check_daily(self, now: datetime):
        s = self.store.settings
        if not s["daily_on"]:
            return
        key = f"daily:{now.date().isoformat()}"
        if self.store.was_fired(key) or now.hour * 60 + now.minute < hhmm_to_min(s["daily_time"]):
            return
        self.store.mark_fired(key)
        self.notify("Chào buổi sáng! ☀️", self.summary(now))

    def _check_interval(self, now: datetime):
        s = self.store.settings
        if not s["interval_on"]:
            return
        minutes = now.hour * 60 + now.minute
        if not hhmm_to_min(s["interval_from"]) <= minutes <= hhmm_to_min(s["interval_to"]):
            return
        if now.timestamp() - s["last_interval"] < s["interval_hours"] * 3600:
            return
        self.store.set_setting("last_interval", now.timestamp())
        todos = self.store.open_todos()
        if todos:
            todos.sort(key=lambda t: -t.prio)
            lines = "\n".join(f"• {t.text}" for t in todos[:5])
            more = f"\n…và {len(todos) - 5} việc nữa" if len(todos) > 5 else ""
            self.notify(f"Còn {len(todos)} việc chưa xong", lines + more)

    def summary(self, now: datetime) -> str:
        evs = self.store.events_on(now.date())
        todos = self.store.open_todos()
        parts = [f"Hôm nay bạn có {len(evs)} lịch và {len(todos)} việc chưa xong."]
        parts += [f"• {e.start or 'Cả ngày'} {e.title}" for e in evs[:4]]
        parts += [f"☐ {t.text}" for t in sorted(todos, key=lambda t: -t.prio)[:3]]
        return "\n".join(parts)
