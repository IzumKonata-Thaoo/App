"""Ba chế độ xem lịch: Tháng, Tuần, Năm (vẽ bằng QPainter)."""
from __future__ import annotations

from calendar import monthrange
from datetime import date, datetime, timedelta
from math import ceil

from PySide6.QtCore import QPointF, QRectF, Qt, Signal
from PySide6.QtGui import QColor, QFont, QFontMetrics, QPainter
from PySide6.QtWidgets import QWidget

from . import theme
from .data import Event, Store, min_to_hhmm
from .theme import ACCENT, ACCENT_SOFT, GRID, INK, LAVENDER, MUTED, OTHER_MONTH, PALETTE, WEEKDAYS

AL = Qt.AlignLeft | Qt.AlignVCenter
AC = Qt.AlignCenter


def draw_chip(p: QPainter, rect: QRectF, text: str, color: str, strike: bool = False):
    bg, fg = PALETTE[color]
    p.setPen(Qt.NoPen)
    p.setBrush(QColor(bg))
    p.drawRoundedRect(rect, 7, 7)
    p.setBrush(QColor(fg))
    p.drawRoundedRect(QRectF(rect.left() + 4, rect.top() + 4, 3, rect.height() - 8), 1.5, 1.5)
    p.setPen(QColor(fg))
    fm = p.fontMetrics()
    p.drawText(rect.adjusted(12, 0, -4, 0), AL, fm.elidedText(text, Qt.ElideRight, max(0, int(rect.width() - 16))))


def layout_columns(items):
    """items: [(start, end, obj)] -> [(obj, col, ncols, start, end)] cho các sự kiện chồng nhau."""
    items = sorted(items, key=lambda x: (x[0], x[1]))
    out, cluster, cluster_end = [], [], -1

    def flush():
        cols, placed = [], []
        for s, e, o in cluster:
            for i, ce in enumerate(cols):
                if ce <= s:
                    cols[i] = e
                    placed.append((o, i, s, e))
                    break
            else:
                cols.append(e)
                placed.append((o, len(cols) - 1, s, e))
        out.extend((o, i, len(cols), s, e) for o, i, s, e in placed)

    for it in items:
        if cluster and it[0] >= cluster_end:
            flush()
            cluster, cluster_end = [], -1
        cluster.append(it)
        cluster_end = max(cluster_end, it[1])
    if cluster:
        flush()
    return out


class BaseView(QWidget):
    daySelected = Signal(object)  # date
    dayActivated = Signal(object)  # double-click ô ngày -> thêm lịch
    eventClicked = Signal(object)  # Event
    slotActivated = Signal(object, int)  # date, phút
    monthOpened = Signal(object)  # date (từ chế độ xem năm)

    def __init__(self, store: Store):
        super().__init__()
        self.store = store
        self.current = date.today()
        self.hits: list[tuple[QRectF, str, object]] = []
        self.setMinimumSize(420, 320)
        store.changed.connect(self.update)

    def set_date(self, d: date):
        self.current = d
        self.update()

    def hit_at(self, pos):
        pt = QPointF(pos)
        for rect, kind, payload in reversed(self.hits):
            if rect.contains(pt):
                return kind, payload
        return None, None

    def minute_at(self, pos) -> int:
        return 9 * 60

    def mousePressEvent(self, e):
        if e.button() != Qt.LeftButton:
            return
        kind, payload = self.hit_at(e.position())
        if kind == "event":
            self.eventClicked.emit(payload)
        elif kind in ("day", "slot"):
            self.daySelected.emit(payload)
        elif kind == "month":
            self.daySelected.emit(payload)

    def mouseDoubleClickEvent(self, e):
        kind, payload = self.hit_at(e.position())
        if kind == "day":
            self.dayActivated.emit(payload)
        elif kind == "slot":
            self.slotActivated.emit(payload, self.minute_at(e.position()))
        elif kind == "month":
            self.monthOpened.emit(payload)

    def _painter(self) -> QPainter:
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        p.setRenderHint(QPainter.TextAntialiasing)
        self.hits = []
        return p

    @staticmethod
    def _font(p: QPainter, size: float, bold=False):
        f = QFont(p.font())
        f.setPointSizeF(size)
        f.setBold(bold)
        p.setFont(f)


# ====================================================================
class MonthView(BaseView):
    HEAD_H = 30

    def paintEvent(self, _):
        p = self._painter()
        W, H = self.width(), self.height()
        cur = self.current
        first = cur.replace(day=1)
        offset = first.weekday()
        rows = ceil((offset + monthrange(cur.year, cur.month)[1]) / 7)
        start = first - timedelta(days=offset)
        cw, ch = W / 7, (H - self.HEAD_H) / rows
        today = date.today()

        self._font(p, 9, True)
        for c, name in enumerate(WEEKDAYS):
            p.setPen(QColor(theme.DANGER if c == 6 else MUTED))
            p.drawText(QRectF(c * cw, 0, cw, self.HEAD_H), AC, name)

        for r in range(rows):
            for c in range(7):
                d = start + timedelta(days=r * 7 + c)
                rect = QRectF(c * cw + 3, self.HEAD_H + r * ch + 3, cw - 6, ch - 6)
                self.hits.append((rect, "day", d))
                inside = d.month == cur.month
                p.setBrush(QColor("white") if inside else QColor(OTHER_MONTH))
                if d == cur:
                    p.setPen(theme.pen(LAVENDER, 2.2))
                elif d == today:
                    p.setPen(theme.pen(ACCENT, 1.6))
                else:
                    p.setPen(theme.pen(GRID, 1))
                p.drawRoundedRect(rect, 14, 14)

                # số ngày
                num = QRectF(rect.left() + 8, rect.top() + 6, 24, 24)
                self._font(p, 9.5, True)
                if d == today:
                    p.setPen(Qt.NoPen)
                    p.setBrush(QColor(ACCENT))
                    p.drawEllipse(num)
                    p.setPen(QColor("white"))
                else:
                    p.setPen(QColor(INK if inside else "#CDBBD6") if c < 6 else QColor(theme.DANGER if inside else "#EBBCCB"))
                p.drawText(num, AC, str(d.day))

                items = [("event", e) for e in self.store.events_on(d)] + [("todo", t) for t in self.store.todos_due_on(d)]
                y = rect.top() + 34
                avail = int((rect.bottom() - y - 2) // 20)
                if avail <= 0 or not items:
                    continue
                shown = items if len(items) <= avail else items[: max(avail - 1, 0)]
                self._font(p, 8, True)
                for kind, obj in shown:
                    cr = QRectF(rect.left() + 5, y, rect.width() - 10, 18)
                    if kind == "event":
                        txt = f"{obj.start} {obj.title}" if obj.start else obj.title
                        draw_chip(p, cr, txt, obj.color)
                        self.hits.append((cr, "event", obj))
                    else:
                        draw_chip(p, cr, f"☐ {obj.text}", "yellow")
                    y += 20
                if len(items) > len(shown):
                    p.setPen(QColor(MUTED))
                    p.drawText(QRectF(rect.left() + 8, y, rect.width() - 12, 18), AL, f"+{len(items) - len(shown)} nữa…")


# ====================================================================
class WeekView(BaseView):
    HOUR_H = 50
    HEAD_H = 58
    GUTTER = 50

    def __init__(self, store):
        super().__init__(store)
        self.scroll_y = 7 * self.HOUR_H
        self._top = 0

    def week_days(self):
        ws = self.current - timedelta(days=self.current.weekday())
        return [ws + timedelta(days=i) for i in range(7)]

    def _max_scroll(self):
        return max(0, 24 * self.HOUR_H - (self.height() - self._top))

    def wheelEvent(self, e):
        self.scroll_y = max(0, min(self._max_scroll(), self.scroll_y - e.angleDelta().y() / 2))
        self.update()

    def minute_at(self, pos) -> int:
        m = (pos.y() - self._top + self.scroll_y) / self.HOUR_H * 60
        return int(max(0, min(23 * 60, round(m / 30) * 30)))

    def paintEvent(self, _):
        p = self._painter()
        W, H = self.width(), self.height()
        days = self.week_days()
        today = date.today()
        cw = (W - self.GUTTER) / 7

        timed = {d: [] for d in days}
        allday = {d: [] for d in days}
        for d in days:
            for ev in self.store.events_on(d):
                (timed if ev.start else allday)[d].append(ev)
        todos = {d: self.store.todos_due_on(d) for d in days}
        strip_rows = min(4, max(len(allday[d]) + len(todos[d]) for d in days))
        strip_h = strip_rows * 20 + 8 if strip_rows else 6
        top = self.HEAD_H + strip_h
        self._top = top
        self.scroll_y = max(0, min(self.scroll_y, self._max_scroll()))

        # ---- lưới giờ (có clip) ----
        p.save()
        p.setClipRect(QRectF(0, top, W, H - top))
        for i, d in enumerate(days):
            col = QRectF(self.GUTTER + i * cw + 2, top, cw - 4, H - top)
            self.hits.append((col, "slot", d))
            if d == self.current:
                p.fillRect(col, QColor("#FFF1F7"))
            elif d == today:
                p.fillRect(col, QColor("#FFF8FB"))
        self._font(p, 8)
        for h in range(25):
            y = top + h * self.HOUR_H - self.scroll_y
            p.setPen(theme.pen(GRID, 1))
            p.drawLine(QPointF(self.GUTTER - 6, y), QPointF(W, y))
            if 0 < h < 24 and y > top + 6:
                p.setPen(QColor(MUTED))
                p.drawText(QRectF(0, y - 9, self.GUTTER - 10, 18), Qt.AlignRight | Qt.AlignVCenter, f"{h:02d}:00")
        for i in range(8):
            x = self.GUTTER + i * cw
            p.setPen(theme.pen(GRID, 1))
            p.drawLine(QPointF(x, top), QPointF(x, H))

        for i, d in enumerate(days):
            items = [(s, e, ev) for ev in timed[d] for (s, e) in [ev.span_minutes()]]
            for ev, ci, n, s, e in layout_columns(items):
                w = (cw - 6) / n
                x = self.GUTTER + i * cw + 3 + ci * w
                y1 = top + s / 60 * self.HOUR_H - self.scroll_y + 1
                hgt = max(22.0, (e - s) / 60 * self.HOUR_H - 2)
                r = QRectF(x, y1, w - 2, hgt)
                bg, fg = PALETTE[ev.color]
                p.setPen(Qt.NoPen)
                p.setBrush(QColor(bg))
                p.drawRoundedRect(r, 9, 9)
                p.setBrush(QColor(fg))
                p.drawRoundedRect(QRectF(r.left() + 4, r.top() + 5, 3, r.height() - 10), 1.5, 1.5)
                p.setPen(QColor(fg))
                self._font(p, 8, True)
                fm = p.fontMetrics()
                tr = r.adjusted(12, 3, -4, -2)
                p.drawText(tr, Qt.AlignLeft | Qt.AlignTop, fm.elidedText(ev.title, Qt.ElideRight, int(tr.width())))
                if r.height() > 40:
                    self._font(p, 7.5)
                    p.drawText(tr.adjusted(0, 15, 0, 0), Qt.AlignLeft | Qt.AlignTop, f"{min_to_hhmm(s)}–{min_to_hhmm(min(e, 1439))}")
                self.hits.append((r, "event", ev))

            if d == today:
                nm = datetime.now().hour * 60 + datetime.now().minute
                y = top + nm / 60 * self.HOUR_H - self.scroll_y
                p.setPen(theme.pen(ACCENT, 2))
                p.drawLine(QPointF(self.GUTTER + i * cw, y), QPointF(self.GUTTER + (i + 1) * cw, y))
                p.setBrush(QColor(ACCENT))
                p.drawEllipse(QPointF(self.GUTTER + i * cw, y), 4, 4)
        p.restore()

        # ---- tiêu đề ngày + dải "cả ngày" ----
        p.fillRect(QRectF(0, 0, W, top), QColor(theme.BG))
        for i, d in enumerate(days):
            x = self.GUTTER + i * cw
            head = QRectF(x + 2, 2, cw - 4, self.HEAD_H - 4)
            self.hits.append((head, "day", d))
            self._font(p, 8.5, True)
            p.setPen(QColor(theme.DANGER if i == 6 else MUTED))
            p.drawText(QRectF(x, 4, cw, 18), AC, WEEKDAYS[i])
            circ = QRectF(x + cw / 2 - 15, 24, 30, 30)
            if d == today:
                p.setPen(Qt.NoPen)
                p.setBrush(QColor(ACCENT))
                p.drawEllipse(circ)
                p.setPen(QColor("white"))
            elif d == self.current:
                p.setPen(theme.pen(LAVENDER, 2))
                p.setBrush(Qt.NoBrush)
                p.drawEllipse(circ)
                p.setPen(QColor(INK))
            else:
                p.setPen(QColor(INK))
            self._font(p, 11, True)
            p.drawText(circ, AC, str(d.day))

            y = self.HEAD_H + 2
            self._font(p, 8, True)
            rows = [("event", e) for e in allday[d]] + [("todo", t) for t in todos[d]]
            for kind, obj in rows[:strip_rows]:
                cr = QRectF(x + 3, y, cw - 6, 18)
                if kind == "event":
                    draw_chip(p, cr, obj.title, obj.color)
                    self.hits.append((cr, "event", obj))
                else:
                    draw_chip(p, cr, f"☐ {obj.text}", "yellow")
                y += 20
        p.setPen(theme.pen(GRID, 1))
        p.drawLine(QPointF(0, top), QPointF(W, top))


# ====================================================================
class YearView(BaseView):
    def __init__(self, store):
        super().__init__(store)
        self._marks: dict[int, dict[date, str]] = {}
        self._marks_ver = -1

    def _year_marks(self, year: int) -> dict[date, str]:
        if self._marks_ver != self.store.version:
            self._marks, self._marks_ver = {}, self.store.version
        if year not in self._marks:
            marks = {}
            d, end = date(year, 1, 1), date(year, 12, 31)
            while d <= end:
                evs = self.store.events_on(d)
                if evs:
                    marks[d] = evs[0].color
                elif self.store.todos_due_on(d):
                    marks[d] = "yellow"
                d += timedelta(days=1)
            self._marks[year] = marks
        return self._marks[year]

    def paintEvent(self, _):
        p = self._painter()
        W, H = self.width(), self.height()
        year = self.current.year
        marks = self._year_marks(year)
        today = date.today()
        cols = 4 if W >= 980 else 3 if W >= 640 else 2
        rows = ceil(12 / cols)
        cw, ch = W / cols, H / rows

        for m in range(1, 13):
            r, c = divmod(m - 1, cols)
            card = QRectF(c * cw + 5, r * ch + 5, cw - 10, ch - 10)
            p.setPen(theme.pen(ACCENT if (year, m) == (today.year, today.month) else GRID, 1.6))
            p.setBrush(QColor("white"))
            p.drawRoundedRect(card, 16, 16)

            title = QRectF(card.left() + 12, card.top() + 6, card.width() - 24, 24)
            self.hits.append((title, "month", date(year, m, 1)))
            self._font(p, 10, True)
            p.setPen(QColor(ACCENT if (year, m) == (today.year, today.month) else INK))
            p.drawText(title, AL, f"Tháng {m}")

            gx, gy = card.left() + 8, card.top() + 52
            dw, dh = (card.width() - 16) / 7, (card.height() - 58) / 6
            self._font(p, 7.5, True)
            for i, name in enumerate(WEEKDAYS):
                p.setPen(QColor(theme.DANGER if i == 6 else MUTED))
                p.drawText(QRectF(gx + i * dw, card.top() + 32, dw, 16), AC, name)

            first = date(year, m, 1)
            for n in range(monthrange(year, m)[1]):
                d = first + timedelta(days=n)
                idx = first.weekday() + n
                cell = QRectF(gx + (idx % 7) * dw, gy + (idx // 7) * dh, dw, dh)
                self.hits.append((cell, "day", d))
                dia = min(dw, dh) - 3
                circ = QRectF(cell.center().x() - dia / 2, cell.center().y() - dia / 2 - 1, dia, dia)
                if d == today:
                    p.setPen(Qt.NoPen)
                    p.setBrush(QColor(ACCENT))
                    p.drawEllipse(circ)
                    p.setPen(QColor("white"))
                elif d in marks:
                    p.setPen(Qt.NoPen)
                    p.setBrush(QColor(PALETTE[marks[d]][0]))
                    p.drawEllipse(circ)
                    p.setPen(QColor(PALETTE[marks[d]][1]))
                else:
                    p.setPen(QColor(theme.DANGER if d.weekday() == 6 else INK))
                if d == self.current:
                    q = QColor(LAVENDER)
                    p.save()
                    p.setPen(theme.pen(LAVENDER, 2))
                    p.setBrush(Qt.NoBrush)
                    p.drawEllipse(circ.adjusted(-1, -1, 1, 1))
                    p.restore()
                self._font(p, 7.5, d in marks or d == today)
                p.drawText(circ, AC, str(d.day))
