"""Mô hình dữ liệu, lưu trữ JSON và logic lặp lịch."""
from __future__ import annotations

import json
import os
import uuid
from calendar import monthrange
from dataclasses import asdict, dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path

from PySide6.QtCore import QObject, Signal

REPEATS = [
    ("none", "Không lặp"),
    ("daily", "Hằng ngày"),
    ("weekly", "Hằng tuần"),
    ("monthly", "Hằng tháng"),
    ("yearly", "Hằng năm"),
]

DEFAULT_SETTINGS = {
    "daily_on": True,
    "daily_time": "08:00",
    "interval_on": False,
    "interval_hours": 2.0,
    "interval_from": "08:00",
    "interval_to": "22:00",
    "sound_on": True,
    "last_interval": 0.0,
}


def data_dir() -> Path:
    p = Path(os.environ.get("MOCHI_PLANNER_DIR") or Path.home() / ".mochi_planner")
    p.mkdir(parents=True, exist_ok=True)
    return p


def new_id() -> str:
    return uuid.uuid4().hex[:12]


def hhmm_to_min(s: str) -> int:
    h, m = s.split(":")
    return int(h) * 60 + int(m)


def min_to_hhmm(m: int) -> str:
    m = max(0, min(m, 24 * 60 - 1))
    return f"{m // 60:02d}:{m % 60:02d}"


@dataclass
class Event:
    title: str
    date: str  # ISO yyyy-mm-dd
    start: str | None = None  # "HH:MM"; None = cả ngày
    end: str | None = None
    repeat: str = "none"
    remind: int | None = 10  # phút nhắc trước; None = không nhắc
    color: str = "pink"
    note: str = ""
    id: str = field(default_factory=new_id)

    @property
    def day(self) -> date:
        return date.fromisoformat(self.date)

    def occurs_on(self, d: date) -> bool:
        first = self.day
        if d < first:
            return False
        if self.repeat == "none":
            return d == first
        if self.repeat == "daily":
            return True
        if self.repeat == "weekly":
            return d.weekday() == first.weekday()
        last = monthrange(d.year, d.month)[1]
        if self.repeat == "monthly":
            return d.day == min(first.day, last)
        if self.repeat == "yearly":
            return d.month == first.month and d.day == min(first.day, last)
        return False

    def span_minutes(self) -> tuple[int, int] | None:
        """(bắt đầu, kết thúc) tính bằng phút trong ngày, None nếu cả ngày."""
        if not self.start:
            return None
        s = hhmm_to_min(self.start)
        e = hhmm_to_min(self.end) if self.end else s + 60
        if e <= s:
            e = s + 60
        return s, min(e, 24 * 60)


@dataclass
class Todo:
    text: str
    done: bool = False
    due: str | None = None
    prio: int = 1  # 1 thường, 2 quan trọng, 3 gấp
    id: str = field(default_factory=new_id)


class Store(QObject):
    changed = Signal()
    settingsChanged = Signal()

    def __init__(self, path: Path | None = None):
        super().__init__()
        self.path = path or data_dir() / "data.json"
        self.events: list[Event] = []
        self.todos: list[Todo] = []
        self.settings = dict(DEFAULT_SETTINGS)
        self.fired: dict[str, str] = {}
        self.version = 0
        self.load()

    # ---- lưu / đọc -------------------------------------------------
    def load(self):
        if not self.path.exists():
            return
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
            self.events = [Event(**e) for e in raw.get("events", [])]
            self.todos = [Todo(**t) for t in raw.get("todos", [])]
            self.settings.update(raw.get("settings", {}))
            self.fired = dict(raw.get("fired", {}))
        except Exception:
            self.path.replace(self.path.with_suffix(".bak"))

    def save(self):
        raw = {
            "events": [asdict(e) for e in self.events],
            "todos": [asdict(t) for t in self.todos],
            "settings": self.settings,
            "fired": self.fired,
        }
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(raw, ensure_ascii=False, indent=1), encoding="utf-8")
        tmp.replace(self.path)

    def _touch(self):
        self.version += 1
        self.save()
        self.changed.emit()

    # ---- lịch ------------------------------------------------------
    def events_on(self, d: date) -> list[Event]:
        evs = [e for e in self.events if e.occurs_on(d)]
        return sorted(evs, key=lambda e: (e.start or "", e.title.lower()))

    def upsert_event(self, ev: Event):
        for i, old in enumerate(self.events):
            if old.id == ev.id:
                self.events[i] = ev
                break
        else:
            self.events.append(ev)
        self._touch()

    def delete_event(self, ev_id: str):
        self.events = [e for e in self.events if e.id != ev_id]
        self._touch()

    # ---- việc cần làm ----------------------------------------------
    def todos_due_on(self, d: date) -> list[Todo]:
        iso = d.isoformat()
        return [t for t in self.todos if t.due == iso and not t.done]

    def open_todos(self) -> list[Todo]:
        return [t for t in self.todos if not t.done]

    def add_todo(self, text: str, due: str | None, prio: int):
        self.todos.append(Todo(text=text, due=due, prio=prio))
        self._touch()

    def set_todo_done(self, todo_id: str, done: bool):
        for t in self.todos:
            if t.id == todo_id:
                t.done = done
        self._touch()

    def delete_todo(self, todo_id: str):
        self.todos = [t for t in self.todos if t.id != todo_id]
        self._touch()

    def clear_done(self):
        self.todos = [t for t in self.todos if not t.done]
        self._touch()

    # ---- cài đặt / nhắc nhở ----------------------------------------
    def set_setting(self, key: str, value):
        if self.settings.get(key) == value:
            return
        self.settings[key] = value
        self.save()
        self.settingsChanged.emit()

    def was_fired(self, key: str) -> bool:
        return key in self.fired

    def mark_fired(self, key: str):
        self.fired[key] = date.today().isoformat()
        cutoff = (date.today() - timedelta(days=3)).isoformat()
        self.fired = {k: v for k, v in self.fired.items() if v >= cutoff}
        self.save()


def add_months(d: date, n: int) -> date:
    y, m = divmod(d.year * 12 + d.month - 1 + n, 12)
    m += 1
    return date(y, m, min(d.day, monthrange(y, m)[1]))


def now() -> datetime:
    return datetime.now()
