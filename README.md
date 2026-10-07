# 🌸 Mochi Planner

Ứng dụng **desktop** xếp lịch & quản lý việc cần làm, giao diện pastel dễ thương. Viết bằng Python + PySide6 (Qt), chạy trên Windows / macOS / Linux.

## Tính năng

- **Lịch Tháng / Tuần / Năm** – chuyển nhanh bằng nút phía trên hoặc `Ctrl+1/2/3`.
  - Tháng: xem các lịch & việc đến hạn ngay trong từng ô ngày.
  - Tuần: lưới theo giờ, sự kiện chồng nhau tự chia cột, vạch giờ hiện tại, cuộn bằng chuột.
  - Năm: 12 tháng thu nhỏ, ngày có lịch được tô màu pastel.
- **Sắp xếp thời gian**: thêm lịch có giờ bắt đầu/kết thúc hoặc cả ngày, lặp lại (ngày/tuần/tháng/năm), 6 màu pastel, ghi chú.
  Nhấp đôi vào ô ngày (hoặc khung giờ trong chế độ tuần) để thêm nhanh, nhấp vào lịch để sửa/xóa.
- **Todo-list**: mức ưu tiên (🌷 thường / 🌼 quan trọng / 🔥 gấp), hạn chót, thanh tiến độ, lọc Tất cả / Chưa xong / Đã xong.
- **Tự nhắc nhở**
  - Nhắc từng lịch trước 0 phút – 1 ngày (chọn khi tạo lịch).
  - Nhắc **mỗi ngày** vào giờ bạn chọn (tóm tắt lịch & việc chưa xong).
  - Nhắc việc chưa xong **sau mỗi X giờ** (0.5 – 24 giờ) trong khung giờ bạn chọn.
  - Thẻ thông báo nổi + thông báo hệ thống + âm thanh, có nút "Nhắc lại sau 5 phút".
  - Đóng cửa sổ sẽ thu nhỏ xuống khay hệ thống để vẫn nhắc; chọn **Thoát** ở menu khay để tắt hẳn.

Phím tắt: `Ctrl+N` thêm lịch · `Ctrl+T` về hôm nay · `Ctrl+←/→` kỳ trước/sau.

## Chạy ứng dụng

```bash
pip install -r requirements.txt
python main.py
```

Dữ liệu lưu ở `~/.mochi_planner/data.json` (đổi thư mục bằng biến môi trường `MOCHI_PLANNER_DIR`).

## Đóng gói thành file chạy (tùy chọn)

```bash
pip install pyinstaller
pyinstaller --noconsole --name MochiPlanner main.py
```

## Cấu trúc

```
main.py                    điểm khởi động
planner/data.py            mô hình dữ liệu, lưu JSON, quy tắc lặp lịch
planner/theme.py           bảng màu pastel, biểu tượng, stylesheet
planner/calendar_views.py  chế độ xem Tháng / Tuần / Năm
planner/panels.py          panel Lịch trong ngày, Todo-list, Nhắc nhở
planner/dialogs.py         hộp thoại thêm/sửa lịch
planner/reminders.py       bộ máy nhắc nhở, thẻ thông báo, âm thanh
planner/window.py          cửa sổ chính, khay hệ thống
```
