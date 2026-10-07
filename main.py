"""Mochi Planner – ứng dụng lịch & việc cần làm màu pastel."""
import sys

from PySide6.QtWidgets import QApplication

from planner import theme
from planner.data import Store
from planner.window import MainWindow


def main() -> int:
    app = QApplication(sys.argv)
    app.setApplicationName("Mochi Planner")
    app.setQuitOnLastWindowClosed(False)  # vẫn chạy nền ở khay hệ thống
    app.setStyleSheet(theme.stylesheet())
    app.setWindowIcon(theme.make_icon())
    store = Store()
    win = MainWindow(store)
    win.show()
    app.lastWindowClosed.connect(lambda: None)
    code = app.exec()
    store.save()
    return code


if __name__ == "__main__":
    sys.exit(main())
