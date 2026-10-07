"""Bảng màu pastel, biểu tượng và stylesheet."""
from __future__ import annotations

from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import QBrush, QColor, QIcon, QLinearGradient, QPainter, QPainterPath, QPen, QPixmap

# tên -> (nền pastel, chữ đậm hơn)
PALETTE = {
    "pink": ("#FFD1E3", "#B8446F"),
    "peach": ("#FFE0C2", "#B5651D"),
    "yellow": ("#FFF3B8", "#8A7410"),
    "mint": ("#CFF5DC", "#2E7D57"),
    "sky": ("#C9E6FF", "#2F6FA3"),
    "lavender": ("#E3D4FA", "#6B4BA8"),
}
COLOR_NAMES = {
    "pink": "Hồng", "peach": "Cam đào", "yellow": "Vàng", "mint": "Bạc hà", "sky": "Xanh trời", "lavender": "Tím oải hương",
}

BG = "#FFF6FA"
CARD = "#FFFFFF"
INK = "#5A4A6A"
MUTED = "#A596B3"
ACCENT = "#FF8FBA"
ACCENT_SOFT = "#FFE3EE"
LAVENDER = "#B79CED"
GRID = "#F6E3EE"
OTHER_MONTH = "#FFF0F6"
DANGER = "#E5658B"

FONT_FAMILY = '"Nunito", "Segoe UI", "Noto Sans", "Helvetica Neue", Arial, sans-serif'

WEEKDAYS = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
WEEKDAYS_LONG = ["Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật"]


def make_icon() -> QIcon:
    size = 128
    pm = QPixmap(size, size)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing)
    g = QLinearGradient(0, 0, size, size)
    g.setColorAt(0, QColor("#FFB6D5"))
    g.setColorAt(1, QColor("#C9B2F5"))
    p.setBrush(QBrush(g))
    p.setPen(Qt.NoPen)
    p.drawRoundedRect(QRectF(4, 4, 120, 120), 34, 34)
    p.setBrush(QColor("white"))
    p.drawRoundedRect(QRectF(26, 34, 76, 66), 14, 14)
    p.setBrush(QColor("#FF8FBA"))
    p.drawRoundedRect(QRectF(26, 34, 76, 20), 14, 14)
    p.drawRect(QRectF(26, 44, 76, 10))
    p.setBrush(QColor("white"))
    for x in (46, 82):
        p.drawRoundedRect(QRectF(x - 4, 26, 8, 18), 4, 4)
    heart = QPainterPath()
    cx, cy = 64, 80
    heart.moveTo(cx, cy + 14)
    heart.cubicTo(cx - 24, cy - 2, cx - 12, cy - 16, cx, cy - 5)
    heart.cubicTo(cx + 12, cy - 16, cx + 24, cy - 2, cx, cy + 14)
    p.setBrush(QColor("#FF8FBA"))
    p.drawPath(heart)
    p.end()
    return QIcon(pm)


def check_icon_path() -> str:
    """Tạo (một lần) ảnh dấu ✓ trắng cho checkbox, trả về đường dẫn kiểu url()."""
    from .data import data_dir

    path = data_dir() / "check.png"
    if not path.exists():
        pm = QPixmap(36, 36)
        pm.fill(Qt.transparent)
        p = QPainter(pm)
        p.setRenderHint(QPainter.Antialiasing)
        p.setPen(QPen(QColor("white"), 5, Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin))
        p.drawPolyline([QPointF(8, 19), QPointF(15, 26), QPointF(28, 10)])
        p.end()
        pm.save(str(path))
    return path.as_posix()


def stylesheet() -> str:
    check = check_icon_path()
    return f"""
    * {{ font-family: {FONT_FAMILY}; color: {INK}; font-size: 13px; }}
    QMainWindow, QDialog, QWidget#root {{ background: {BG}; }}
    QToolTip {{ background: {CARD}; color: {INK}; border: 1px solid {GRID}; padding: 4px; }}

    QFrame#card {{ background: {CARD}; border: 1px solid {GRID}; border-radius: 18px; }}
    QLabel {{ background: transparent; }}
    QLabel#h3 {{ font-size: 15px; font-weight: 800; }}
    QLabel#title {{ font-size: 20px; font-weight: 800; }}
    QLabel#brand {{ font-size: 18px; font-weight: 800; }}
    QLabel#muted {{ color: {MUTED}; font-size: 12px; }}
    QLabel#pill {{ background: {ACCENT_SOFT}; color: {ACCENT}; border-radius: 10px; padding: 2px 10px; font-weight: 700; }}

    QPushButton {{ background: {CARD}; border: 1px solid {GRID}; border-radius: 12px; padding: 7px 14px; font-weight: 700; }}
    QPushButton:hover {{ background: {ACCENT_SOFT}; }}
    QPushButton:pressed {{ background: #FFD1E3; }}
    QPushButton#primary {{ background: {ACCENT}; color: white; border: none; }}
    QPushButton#primary:hover {{ background: #FF7BAE; }}
    QPushButton#danger {{ color: {DANGER}; }}
    QPushButton#seg {{ border-radius: 10px; border: none; background: transparent; padding: 6px 14px; color: {MUTED}; }}
    QPushButton#seg:checked {{ background: {CARD}; color: {ACCENT}; }}
    QPushButton#seg:hover:!checked {{ color: {INK}; }}
    QPushButton#link {{ border: none; background: transparent; color: {MUTED}; text-decoration: underline; padding: 4px; }}
    QPushButton#link:hover {{ color: {ACCENT}; }}
    QPushButton#nav {{ min-width: 18px; padding: 6px 12px; font-size: 16px; }}
    QToolButton {{ border: none; background: transparent; color: {MUTED}; font-size: 14px; padding: 2px 6px; border-radius: 8px; }}
    QToolButton:hover {{ background: {ACCENT_SOFT}; color: {DANGER}; }}
    QFrame#segbar {{ background: #F9E8F1; border-radius: 13px; }}

    QLineEdit, QDateEdit, QTimeEdit, QComboBox, QDoubleSpinBox, QPlainTextEdit {{
        background: {CARD}; border: 1.5px solid {GRID}; border-radius: 10px; padding: 6px 8px; selection-background-color: {ACCENT};
        selection-color: white; }}
    QLineEdit:focus, QDateEdit:focus, QTimeEdit:focus, QComboBox:focus, QDoubleSpinBox:focus, QPlainTextEdit:focus {{ border-color: {ACCENT}; }}
    QTimeEdit::up-button, QTimeEdit::down-button, QDoubleSpinBox::up-button, QDoubleSpinBox::down-button {{ width: 0; border: none; }}
    QTimeEdit, QDoubleSpinBox {{ min-width: 64px; }}
    QComboBox::drop-down, QDateEdit::drop-down {{ border: none; width: 22px; }}
    QComboBox QAbstractItemView {{ background: {CARD}; border: 1px solid {GRID}; selection-background-color: {ACCENT_SOFT};
        selection-color: {INK}; outline: none; }}
    QCalendarWidget QWidget {{ background: {CARD}; }}
    QCalendarWidget QAbstractItemView:enabled {{ selection-background-color: {ACCENT}; selection-color: white; }}

    QCheckBox {{ spacing: 8px; background: transparent; }}
    QCheckBox::indicator {{ width: 18px; height: 18px; border-radius: 6px; border: 2px solid #E8C9DA; background: {CARD}; }}
    QCheckBox::indicator:hover {{ border-color: {ACCENT}; }}
    QCheckBox::indicator:checked {{ background: {ACCENT}; border-color: {ACCENT}; image: url({check}); }}

    QProgressBar {{ background: #F9E8F1; border: none; border-radius: 5px; max-height: 10px; min-height: 10px; text-align: center; }}
    QProgressBar::chunk {{ border-radius: 5px; background: qlineargradient(x1:0,y1:0,x2:1,y2:0, stop:0 #FFB6D5, stop:1 #C9B2F5); }}

    QScrollArea {{ background: transparent; border: none; }}
    QScrollArea > QWidget > QWidget {{ background: transparent; }}
    QScrollBar:vertical {{ background: transparent; width: 10px; margin: 2px; }}
    QScrollBar::handle:vertical {{ background: #F0CFE0; border-radius: 4px; min-height: 30px; }}
    QScrollBar::add-line, QScrollBar::sub-line {{ height: 0; }}
    QScrollBar::add-page, QScrollBar::sub-page {{ background: transparent; }}

    QMenu {{ background: {CARD}; border: 1px solid {GRID}; border-radius: 10px; padding: 6px; }}
    QMenu::item {{ padding: 6px 18px; border-radius: 6px; }}
    QMenu::item:selected {{ background: {ACCENT_SOFT}; }}
    QFrame#toast {{ background: {CARD}; border: 2px solid #FFC2DA; border-radius: 18px; }}
    """


def qcolor(hex_: str, alpha: int = 255) -> QColor:
    c = QColor(hex_)
    c.setAlpha(alpha)
    return c


def pen(color: str, w: float = 1.0) -> QPen:
    return QPen(QColor(color), w)


__all__ = ["PALETTE", "QPointF"]
