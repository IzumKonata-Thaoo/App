"""Cửa sổ chính."""
from __future__ import annotations

from datetime import date, datetime, timedelta

from PySide6.QtCore import Qt
from PySide6.QtGui import QAction, QKeySequence, QShortcut
from PySide6.QtWidgets import (
    QApplication, QButtonGroup, QFrame, QHBoxLayout, QLabel, QMainWindow, QMenu, QPushButton, QScrollArea,
    QStackedWidget, QSystemTrayIcon, QVBoxLayout, QWidget,
)

from . import theme
from .calendar_views import MonthView, WeekView, YearView
from .data import Event, Store, add_months, min_to_hhmm
from .dialogs import EventDialog
from .panels import AgendaPanel, ReminderPanel, TodoPanel
from .reminders import ReminderEngine

VIEWS = ("month", "week", "year")


class MainWindow(QMainWindow):
    def __init__(self, store: Store):
        super().__init__()
        self.store = store
        self.current = date.today()
        self.mode = "month"
        self._quitting = False
        self.setWindowTitle("Mochi Planner")
        self.setWindowIcon(theme.make_icon())
        self.resize(1360, 860)
        self.setMinimumSize(980, 640)

        self.tray = None
        if QSystemTrayIcon.isSystemTrayAvailable():
            self.tray = QSystemTrayIcon(theme.make_icon(), self)
            self.tray.setToolTip("Mochi Planner")
            menu = QMenu()
            menu.addAction("Mở Mochi Planner", self.show_normal)
            menu.addAction("Thoát", self.quit)
            self.tray.setContextMenu(menu)
            self.tray.activated.connect(lambda r: r == QSystemTrayIcon.Trigger and self.show_normal())
            self.tray.show()
        self.engine = ReminderEngine(store, self.tray)

        root = QWidget()
        root.setObjectName("root")
        self.setCentralWidget(root)
        outer = QHBoxLayout(root)
        outer.setContentsMargins(18, 14, 18, 18)
        outer.setSpacing(16)

        # ---- cột trái: thanh công cụ + lịch ----
        left = QVBoxLayout()
        left.setSpacing(12)
        left.addLayout(self._toolbar())
        self.stack = QStackedWidget()
        self.month, self.week, self.year = MonthView(store), WeekView(store), YearView(store)
        for v in (self.month, self.week, self.year):
            self.stack.addWidget(v)
            v.daySelected.connect(self.select_day)
            v.dayActivated.connect(lambda d: self.new_event(d))
            v.eventClicked.connect(self.edit_event)
            v.slotActivated.connect(lambda d, m: self.new_event(d, m))
            v.monthOpened.connect(self._open_month)
        card = QFrame()
        card.setObjectName("card")
        cl = QVBoxLayout(card)
        cl.setContentsMargins(12, 10, 12, 12)
        cl.addWidget(self.stack)
        left.addWidget(card, 1)
        outer.addLayout(left, 1)

        # ---- cột phải ----
        self.agenda = AgendaPanel(store)
        self.todo = TodoPanel(store)
        self.remind = ReminderPanel(store)
        self.agenda.editRequested.connect(self.edit_event)
        self.agenda.addRequested.connect(lambda: self.new_event(self.current))
        self.remind.testRequested.connect(
            lambda: self.engine.notify("Thử nhắc nhở 🌸", self.engine.summary(datetime.now())))
        side = QWidget()
        sl = QVBoxLayout(side)
        sl.setContentsMargins(0, 0, 6, 0)
        sl.setSpacing(14)
        for w in (self.agenda, self.todo, self.remind):
            sl.addWidget(w)
        sl.addStretch()
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.setWidget(side)
        scroll.setFixedWidth(396)
        outer.addWidget(scroll)

        for i, key in enumerate(VIEWS):
            QShortcut(QKeySequence(f"Ctrl+{i + 1}"), self, activated=lambda k=key: self.set_mode(k))
        QShortcut(QKeySequence("Ctrl+N"), self, activated=lambda: self.new_event(self.current))
        QShortcut(QKeySequence("Ctrl+T"), self, activated=self.go_today)
        QShortcut(QKeySequence("Ctrl+Left"), self, activated=lambda: self.shift(-1))
        QShortcut(QKeySequence("Ctrl+Right"), self, activated=lambda: self.shift(1))
        self.refresh()

    # ---- thanh công cụ -------------------------------------------------
    def _toolbar(self):
        bar = QHBoxLayout()
        bar.setSpacing(10)
        logo = QLabel()
        logo.setPixmap(theme.make_icon().pixmap(40, 40))
        bar.addWidget(logo)
        col = QVBoxLayout()
        col.setSpacing(0)
        brand = QLabel("Mochi Planner")
        brand.setObjectName("brand")
        self.greeting = QLabel()
        self.greeting.setObjectName("muted")
        col.addWidget(brand)
        col.addWidget(self.greeting)
        bar.addLayout(col)
        bar.addSpacing(18)

        prev, nxt, today = QPushButton("‹"), QPushButton("›"), QPushButton("Hôm nay")
        for b in (prev, nxt):
            b.setObjectName("nav")
        prev.clicked.connect(lambda: self.shift(-1))
        nxt.clicked.connect(lambda: self.shift(1))
        today.clicked.connect(self.go_today)
        for w in (prev, today, nxt):
            bar.addWidget(w)
        self.title = QLabel()
        self.title.setObjectName("title")
        self.title.setMinimumWidth(150)
        bar.addWidget(self.title)
        bar.addStretch()

        seg = QFrame()
        seg.setObjectName("segbar")
        sl = QHBoxLayout(seg)
        sl.setContentsMargins(3, 3, 3, 3)
        sl.setSpacing(2)
        self.mode_group = QButtonGroup(self)
        self.mode_buttons = {}
        for key, label in (("month", "Tháng"), ("week", "Tuần"), ("year", "Năm")):
            b = QPushButton(label)
            b.setObjectName("seg")
            b.setCheckable(True)
            b.setMinimumWidth(b.sizeHint().width())
            b.setChecked(key == self.mode)
            b.clicked.connect(lambda _=False, k=key: self.set_mode(k))
            self.mode_group.addButton(b)
            self.mode_buttons[key] = b
            sl.addWidget(b)
        bar.addWidget(seg)
        add = QPushButton("＋ Thêm lịch")
        add.setObjectName("primary")
        add.clicked.connect(lambda: self.new_event(self.current))
        bar.addWidget(add)
        return bar

    # ---- điều hướng ------------------------------------------------------
    def set_mode(self, mode: str):
        self.mode = mode
        self.mode_buttons[mode].setChecked(True)
        self.refresh()

    def shift(self, step: int):
        if self.mode == "month":
            self.current = add_months(self.current, step)
        elif self.mode == "week":
            self.current += timedelta(days=7 * step)
        else:
            self.current = add_months(self.current, 12 * step)
        self.refresh()

    def go_today(self):
        self.current = date.today()
        self.refresh()

    def select_day(self, d: date):
        self.current = d
        self.refresh()

    def _open_month(self, d: date):
        self.current = d
        self.set_mode("month")

    def refresh(self):
        view = {"month": self.month, "week": self.week, "year": self.year}[self.mode]
        self.stack.setCurrentWidget(view)
        for v in (self.month, self.week, self.year):
            v.set_date(self.current)
        self.agenda.set_date(self.current)
        d = self.current
        if self.mode == "month":
            self.title.setText(f"Tháng {d.month}, {d.year}")
        elif self.mode == "year":
            self.title.setText(f"Năm {d.year}")
        else:
            days = self.week.week_days()
            a, b = days[0], days[-1]
            same = a.month == b.month
            self.title.setText(f"{a.day}{'' if same else f'/{a.month}'} – {b.day}/{b.month}, {b.year}")
        h = datetime.now().hour
        hello = "Chào buổi sáng" if h < 11 else "Chào buổi trưa" if h < 14 else "Chào buổi chiều" if h < 18 else "Chào buổi tối"
        self.greeting.setText(f"{hello} ✿")

    # ---- sự kiện ---------------------------------------------------------
    def new_event(self, d: date, minute: int | None = None):
        dlg = EventDialog(self, day=d, minute=minute)
        if dlg.exec() and not dlg.deleted:
            ev = dlg.result_event()
            self.store.upsert_event(ev)
            self.current = ev.day
            self.refresh()

    def edit_event(self, ev: Event):
        dlg = EventDialog(self, event=Event(**ev.__dict__))
        if dlg.exec():
            if dlg.deleted:
                self.store.delete_event(ev.id)
            else:
                new = dlg.result_event()
                # đổi giờ/ngày thì cho phép nhắc lại
                self.store.fired = {k: v for k, v in self.store.fired.items() if not k.startswith(f"ev:{ev.id}:")}
                self.store.upsert_event(new)
            self.refresh()

    # ---- thoát / thu nhỏ xuống khay ---------------------------------------
    def show_normal(self):
        self.showNormal()
        self.raise_()
        self.activateWindow()

    def quit(self):
        self._quitting = True
        self.close()
        QApplication.quit()

    def closeEvent(self, e):
        if self.tray is not None and self.tray.isVisible() and not self._quitting:
            e.ignore()
            self.hide()
            self.tray.showMessage("Mochi Planner", "Ứng dụng vẫn chạy nền để nhắc nhở bạn nhé 🌸", QSystemTrayIcon.Information, 4000)
        else:
            e.accept()
            QApplication.quit()
