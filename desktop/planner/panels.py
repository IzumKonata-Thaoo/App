"""Các panel bên phải: lịch trong ngày, todo-list, cài đặt nhắc nhở."""
from __future__ import annotations

from datetime import date

from PySide6.QtCore import QDate, QTime, Qt, Signal
from PySide6.QtWidgets import (
    QButtonGroup, QCheckBox, QComboBox, QDateEdit, QDoubleSpinBox, QFrame, QHBoxLayout, QLabel, QLineEdit,
    QProgressBar, QPushButton, QTimeEdit, QToolButton, QVBoxLayout, QWidget,
)

from . import theme
from .data import Event, Store
from .theme import PALETTE, WEEKDAYS_LONG


def clear_layout(layout):
    while layout.count():
        item = layout.takeAt(0)
        w = item.widget()
        if w is not None:
            w.setParent(None)
            w.deleteLater()
        elif item.layout() is not None:
            clear_layout(item.layout())


class Card(QFrame):
    def __init__(self, title: str):
        super().__init__()
        self.setObjectName("card")
        self.lay = QVBoxLayout(self)
        self.lay.setContentsMargins(16, 14, 16, 14)
        self.lay.setSpacing(10)
        self.head = QHBoxLayout()
        self.title = QLabel(title)
        self.title.setObjectName("h3")
        self.head.addWidget(self.title)
        self.head.addStretch()
        self.lay.addLayout(self.head)


class ClickFrame(QFrame):
    clicked = Signal()

    def mousePressEvent(self, e):
        self.clicked.emit()


# ====================================================================
class AgendaPanel(Card):
    editRequested = Signal(object)
    addRequested = Signal()

    def __init__(self, store: Store):
        super().__init__("📅 Hôm nay")
        self.store = store
        self.day = date.today()
        add = QPushButton("＋")
        add.setToolTip("Thêm lịch vào ngày này")
        add.setFixedWidth(40)
        add.clicked.connect(self.addRequested)
        self.head.addWidget(add)
        self.body = QVBoxLayout()
        self.body.setSpacing(6)
        self.lay.addLayout(self.body)
        store.changed.connect(self.refresh)
        self.refresh()

    def set_date(self, d: date):
        self.day = d
        self.refresh()

    def refresh(self):
        d = self.day
        prefix = "Hôm nay" if d == date.today() else WEEKDAYS_LONG[d.weekday()]
        self.title.setText(f"📅 {prefix}, {d.strftime('%d/%m')}")
        clear_layout(self.body)
        evs, todos = self.store.events_on(d), self.store.todos_due_on(d)
        if not evs and not todos:
            lbl = QLabel("Không có gì cả~ thư giãn nhé ☕")
            lbl.setObjectName("muted")
            self.body.addWidget(lbl)
        for ev in evs:
            self.body.addWidget(self._event_row(ev))
        if todos:
            lbl = QLabel("Việc đến hạn")
            lbl.setObjectName("muted")
            self.body.addWidget(lbl)
            for t in todos:
                self.body.addWidget(QLabel(f"☐ {t.text}"))

    def _event_row(self, ev: Event) -> QWidget:
        bg, fg = PALETTE[ev.color]
        f = ClickFrame()
        f.setCursor(Qt.PointingHandCursor)
        f.setStyleSheet(f"QFrame{{background:{bg};border-radius:12px;}} QLabel{{color:{fg};background:transparent;}}")
        lay = QVBoxLayout(f)
        lay.setContentsMargins(12, 8, 12, 8)
        lay.setSpacing(2)
        when = f"{ev.start}–{ev.end}" if ev.start and ev.end else "Cả ngày"
        icon = {"none": "", "daily": " 🔁", "weekly": " 🔁", "monthly": " 🔁", "yearly": " 🔁"}[ev.repeat]
        bell = " 🔔" if ev.remind is not None else ""
        top = QLabel(f"<b>{ev.title}</b>")
        top.setTextFormat(Qt.RichText)
        sub = QLabel(f"{when}{icon}{bell}")
        sub.setStyleSheet(f"color:{fg};font-size:11px;")
        lay.addWidget(top)
        lay.addWidget(sub)
        if ev.note:
            n = QLabel(ev.note)
            n.setWordWrap(True)
            n.setStyleSheet(f"color:{fg};font-size:11px;")
            lay.addWidget(n)
        f.clicked.connect(lambda: self.editRequested.emit(ev))
        return f


# ====================================================================
PRIO = {1: ("🌷", "#A7D8B8"), 2: ("🌼", "#F2CE6B"), 3: ("🔥", "#F28BAA")}


class TodoPanel(Card):
    def __init__(self, store: Store):
        super().__init__("📝 Việc cần làm")
        self.store = store
        self.filter = "all"
        self.count = QLabel()
        self.count.setObjectName("pill")
        self.head.addWidget(self.count)

        self.bar = QProgressBar()
        self.bar.setTextVisible(False)
        self.lay.addWidget(self.bar)

        self.text = QLineEdit()
        self.text.setPlaceholderText("Thêm việc mới… rồi nhấn Enter ✨")
        self.text.setMaxLength(120)
        self.text.returnPressed.connect(self.add)
        self.lay.addWidget(self.text)

        self.use_due = QCheckBox("Hạn")
        self.due = QDateEdit(QDate.currentDate())
        self.due.setCalendarPopup(True)
        self.due.setDisplayFormat("dd/MM")
        self.due.setEnabled(False)
        self.use_due.toggled.connect(self.due.setEnabled)
        self.prio = QComboBox()
        self.prio.setSizeAdjustPolicy(QComboBox.AdjustToMinimumContentsLengthWithIcon)
        self.prio.setMinimumContentsLength(7)
        self.due.setFixedWidth(86)
        for k, (icon, _) in PRIO.items():
            self.prio.addItem(f"{icon} {['Thường', 'Quan trọng', 'Gấp'][k - 1]}", k)
        add = QPushButton("Thêm")
        add.setObjectName("primary")
        add.clicked.connect(self.add)
        row = QHBoxLayout()
        row.addWidget(self.use_due)
        row.addWidget(self.due)
        row.addWidget(self.prio, 1)
        row.addWidget(add)
        self.lay.addLayout(row)

        seg = QFrame()
        seg.setObjectName("segbar")
        sl = QHBoxLayout(seg)
        sl.setContentsMargins(3, 3, 3, 3)
        sl.setSpacing(2)
        self.group = QButtonGroup(self)
        for key, label in (("all", "Tất cả"), ("open", "Chưa xong"), ("done", "Đã xong")):
            b = QPushButton(label)
            b.setObjectName("seg")
            b.setCheckable(True)
            b.setChecked(key == "all")
            b.clicked.connect(lambda _=False, k=key: self.set_filter(k))
            self.group.addButton(b)
            sl.addWidget(b)
        self.lay.addWidget(seg)

        self.items = QVBoxLayout()
        self.items.setSpacing(4)
        self.lay.addLayout(self.items)
        clear = QPushButton("Xóa các việc đã xong")
        clear.setObjectName("link")
        clear.clicked.connect(store.clear_done)
        self.lay.addWidget(clear, 0, Qt.AlignRight)
        store.changed.connect(self.refresh)
        self.refresh()

    def set_filter(self, key: str):
        self.filter = key
        self.refresh()

    def add(self):
        text = self.text.text().strip()
        if not text:
            return
        due = None
        if self.use_due.isChecked():
            q = self.due.date()
            due = date(q.year(), q.month(), q.day()).isoformat()
        self.text.clear()
        self.store.add_todo(text, due, self.prio.currentData())

    def refresh(self):
        todos = self.store.todos
        done = sum(t.done for t in todos)
        self.count.setText(f"{done}/{len(todos)}")
        self.bar.setMaximum(max(1, len(todos)))
        self.bar.setValue(done)
        clear_layout(self.items)
        shown = [t for t in todos if self.filter == "all" or (self.filter == "done") == t.done]
        shown.sort(key=lambda t: (t.done, -t.prio, t.due or "9999"))
        if not shown:
            lbl = QLabel("Chưa có việc nào ✿" if self.filter != "done" else "Chưa hoàn thành việc nào")
            lbl.setObjectName("muted")
            self.items.addWidget(lbl)
        for t in shown:
            self.items.addWidget(self._row(t))

    def _row(self, t) -> QWidget:
        w = QFrame()
        w.setStyleSheet("QFrame{background:#FFF8FB;border-radius:10px;}")
        lay = QHBoxLayout(w)
        lay.setContentsMargins(8, 4, 4, 4)
        lay.setSpacing(6)
        cb = QCheckBox()
        cb.setChecked(t.done)
        cb.toggled.connect(lambda v, i=t.id: self.store.set_todo_done(i, v))
        lay.addWidget(cb)
        icon = QLabel(PRIO[t.prio][0])
        lay.addWidget(icon)
        label = QLabel(t.text)
        label.setWordWrap(True)
        f = label.font()
        f.setStrikeOut(t.done)
        label.setFont(f)
        if t.done:
            label.setStyleSheet(f"color:{theme.MUTED};")
        lay.addWidget(label, 1)
        if t.due:
            d = date.fromisoformat(t.due)
            delta = (d - date.today()).days
            if t.done:
                bg, fg = "#F3EEF6", theme.MUTED
            elif delta < 0:
                bg, fg = "#FFD6E2", theme.DANGER
            elif delta == 0:
                bg, fg = "#FFF3B8", "#8A7410"
            else:
                bg, fg = "#E3D4FA", "#6B4BA8"
            badge = QLabel(d.strftime("%d/%m"))
            badge.setStyleSheet(f"background:{bg};color:{fg};border-radius:8px;padding:1px 7px;font-size:11px;font-weight:700;")
            lay.addWidget(badge)
        rm = QToolButton()
        rm.setText("✕")
        rm.setCursor(Qt.PointingHandCursor)
        rm.clicked.connect(lambda _=False, i=t.id: self.store.delete_todo(i))
        lay.addWidget(rm)
        return w


# ====================================================================
class ReminderPanel(Card):
    testRequested = Signal()

    def __init__(self, store: Store):
        super().__init__("🔔 Nhắc nhở")
        self.store = store
        s = store.settings

        def time_edit(key):
            t = QTimeEdit(QTime.fromString(s[key], "HH:mm"))
            t.setDisplayFormat("HH:mm")
            t.timeChanged.connect(lambda v: store.set_setting(key, v.toString("HH:mm")))
            return t

        def check(key, text):
            c = QCheckBox(text)
            c.setChecked(bool(s[key]))
            c.toggled.connect(lambda v: store.set_setting(key, v))
            return c

        # nhắc mỗi ngày
        row = QHBoxLayout()
        row.addWidget(check("daily_on", "Nhắc mỗi ngày lúc"))
        row.addStretch()
        row.addWidget(time_edit("daily_time"))
        self.lay.addLayout(row)
        hint = QLabel("Tóm tắt lịch & việc cần làm của ngày.")
        hint.setObjectName("muted")
        self.lay.addWidget(hint)

        # nhắc sau mỗi X giờ
        self.interval_on = check("interval_on", "Nhắc việc chưa xong sau mỗi")
        self.interval_on.toggled.connect(lambda v: v and store.set_setting("last_interval", __import__("time").time()))
        hours = QDoubleSpinBox()
        hours.setRange(0.5, 24)
        hours.setSingleStep(0.5)
        hours.setDecimals(1)
        hours.setSuffix(" giờ")
        hours.setValue(s["interval_hours"])
        hours.valueChanged.connect(lambda v: store.set_setting("interval_hours", v))
        row = QHBoxLayout()
        row.addWidget(self.interval_on)
        row.addStretch()
        row.addWidget(hours)
        self.lay.addLayout(row)
        row = QHBoxLayout()
        row.addWidget(QLabel("trong khung giờ"))
        row.addStretch()
        row.addWidget(time_edit("interval_from"))
        row.addWidget(QLabel("–"))
        row.addWidget(time_edit("interval_to"))
        self.lay.addLayout(row)

        self.lay.addWidget(check("sound_on", "Phát âm thanh khi nhắc 🎵"))
        note = QLabel("Lịch có đặt “Nhắc nhở” sẽ tự báo khi đến giờ. Ứng dụng thu nhỏ xuống khay hệ thống để tiếp tục nhắc.")
        note.setObjectName("muted")
        note.setWordWrap(True)
        self.lay.addWidget(note)
        test = QPushButton("Thử nhắc nhở")
        test.clicked.connect(self.testRequested)
        self.lay.addWidget(test)
