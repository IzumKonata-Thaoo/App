"""Hộp thoại thêm / sửa lịch."""
from __future__ import annotations

from datetime import date

from PySide6.QtCore import QDate, QTime, Qt
from PySide6.QtWidgets import (
    QCheckBox, QComboBox, QDateEdit, QDialog, QFormLayout, QHBoxLayout, QLabel, QLineEdit, QPlainTextEdit,
    QPushButton, QTimeEdit, QToolButton, QVBoxLayout, QWidget,
)

from . import theme
from .data import REPEATS, Event, hhmm_to_min, min_to_hhmm

REMINDERS = [(None, "Không nhắc"), (0, "Đúng giờ"), (5, "Trước 5 phút"), (10, "Trước 10 phút"), (15, "Trước 15 phút"),
             (30, "Trước 30 phút"), (60, "Trước 1 giờ"), (120, "Trước 2 giờ"), (1440, "Trước 1 ngày")]


class EventDialog(QDialog):
    def __init__(self, parent, event: Event | None = None, day: date | None = None, minute: int | None = None):
        super().__init__(parent)
        self.setWindowTitle("Sửa lịch" if event else "Thêm lịch mới")
        self.setModal(True)
        self.setMinimumWidth(420)
        self.deleted = False
        self.event = event
        self.color = event.color if event else "pink"

        self.title = QLineEdit(event.title if event else "")
        self.title.setPlaceholderText("VD: Họp nhóm, học tiếng Nhật, hẹn bạn…")
        d = event.day if event else (day or date.today())
        self.date = QDateEdit(QDate(d.year, d.month, d.day))
        self.date.setCalendarPopup(True)
        self.date.setDisplayFormat("dd/MM/yyyy")

        self.allday = QCheckBox("Cả ngày")
        self.start, self.end = QTimeEdit(), QTimeEdit()
        for t in (self.start, self.end):
            t.setDisplayFormat("HH:mm")
        if event and event.start:
            self.start.setTime(QTime.fromString(event.start, "HH:mm"))
            self.end.setTime(QTime.fromString(event.end or min_to_hhmm(hhmm_to_min(event.start) + 60), "HH:mm"))
        else:
            m = minute if minute is not None else 9 * 60
            self.start.setTime(QTime(m // 60, m % 60))
            m2 = min(m + 60, 23 * 60 + 59)
            self.end.setTime(QTime(m2 // 60, m2 % 60))
        self.allday.setChecked(bool(event) and not event.start)
        self.allday.toggled.connect(self._sync)

        self.repeat = QComboBox()
        for key, label in REPEATS:
            self.repeat.addItem(label, key)
        self.repeat.setCurrentIndex(max(0, self.repeat.findData(event.repeat if event else "none")))

        self.remind = QComboBox()
        for key, label in REMINDERS:
            self.remind.addItem(label, key)
        cur = event.remind if event else 10
        self.remind.setCurrentIndex(max(0, self.remind.findData(cur)))

        self.note = QPlainTextEdit(event.note if event else "")
        self.note.setPlaceholderText("Ghi chú nhỏ…")
        self.note.setFixedHeight(62)

        # ô chọn màu
        sw = QHBoxLayout()
        sw.setSpacing(8)
        self.swatches: dict[str, QToolButton] = {}
        for key, (bg, fg) in theme.PALETTE.items():
            b = QToolButton()
            b.setCheckable(True)
            b.setToolTip(theme.COLOR_NAMES[key])
            b.setFixedSize(30, 30)
            b.setStyleSheet(
                f"QToolButton{{background:{bg};border:2px solid {bg};border-radius:15px;}}"
                f"QToolButton:hover{{background:{bg};border-color:{fg};}}"
                f"QToolButton:checked{{background:{bg};border:3px solid {fg};}}"
            )
            b.clicked.connect(lambda _=False, k=key: self._pick(k))
            self.swatches[key] = b
            sw.addWidget(b)
        sw.addStretch()
        self._pick(self.color)

        time_row = QHBoxLayout()
        time_row.addWidget(self.start)
        time_row.addWidget(QLabel("→"))
        time_row.addWidget(self.end)
        time_row.addWidget(self.allday)

        form = QFormLayout()
        form.setHorizontalSpacing(14)
        form.setVerticalSpacing(10)
        form.addRow("Tiêu đề", self.title)
        form.addRow("Ngày", self.date)
        form.addRow("Giờ", time_row)
        form.addRow("Lặp lại", self.repeat)
        form.addRow("Nhắc nhở", self.remind)
        form.addRow("Màu", self._wrap(sw))
        form.addRow("Ghi chú", self.note)

        ok = QPushButton("Lưu")
        ok.setObjectName("primary")
        ok.setDefault(True)
        ok.clicked.connect(self._accept)
        cancel = QPushButton("Hủy")
        cancel.clicked.connect(self.reject)
        row = QHBoxLayout()
        if event:
            delete = QPushButton("Xóa")
            delete.setObjectName("danger")
            delete.clicked.connect(self._delete)
            row.addWidget(delete)
        row.addStretch()
        row.addWidget(cancel)
        row.addWidget(ok)

        head = QLabel("✿ " + ("Sửa lịch" if event else "Thêm lịch mới"))
        head.setObjectName("title")
        lay = QVBoxLayout(self)
        lay.setContentsMargins(22, 20, 22, 18)
        lay.setSpacing(14)
        lay.addWidget(head)
        lay.addLayout(form)
        lay.addLayout(row)
        self._sync()
        self.title.setFocus()

    @staticmethod
    def _wrap(layout) -> QWidget:
        w = QWidget()
        w.setLayout(layout)
        layout.setContentsMargins(0, 0, 0, 0)
        return w

    def _pick(self, key: str):
        self.color = key
        for k, b in self.swatches.items():
            b.setChecked(k == key)

    def _sync(self):
        on = not self.allday.isChecked()
        self.start.setEnabled(on)
        self.end.setEnabled(on)

    def _delete(self):
        self.deleted = True
        self.accept()

    def _accept(self):
        if not self.title.text().strip():
            self.title.setStyleSheet(f"border-color:{theme.DANGER};")
            self.title.setFocus()
            return
        self.accept()

    def result_event(self) -> Event:
        allday = self.allday.isChecked()
        qd = self.date.date()
        ev = self.event or Event(title="", date="")
        ev.title = self.title.text().strip()
        ev.date = date(qd.year(), qd.month(), qd.day()).isoformat()
        ev.start = None if allday else self.start.time().toString("HH:mm")
        ev.end = None if allday else self.end.time().toString("HH:mm")
        ev.repeat = self.repeat.currentData()
        ev.remind = self.remind.currentData()
        ev.color = self.color
        ev.note = self.note.toPlainText().strip()
        return ev
