# 🌸 Mochi Planner

Ứng dụng **Android** xếp lịch & quản lý việc cần làm, giao diện pastel dễ thương. Viết bằng Flutter.

## Tính năng

- **Lịch Tháng / Tuần / Năm** – chuyển bằng thanh phía trên hoặc vuốt trái/phải để sang kỳ khác.
  - Tháng: lưới ngày có chấm màu, bên dưới là danh sách lịch & việc đến hạn của ngày đang chọn.
  - Tuần: dải 7 ngày + lưới giờ trong ngày (lịch chồng giờ tự chia cột, vạch giờ hiện tại, chạm ô trống để thêm lịch).
  - Năm: 12 tháng thu nhỏ, ngày có lịch được tô màu; chạm vào để mở tháng đó.
- **Xếp lịch**: giờ bắt đầu/kết thúc hoặc cả ngày, lặp lại (ngày/tuần/tháng/năm), 6 màu pastel, ghi chú.
- **Việc cần làm (todo-list)**: ưu tiên 🌷/🌼/🔥, hạn chót, thanh tiến độ, lọc Tất cả/Chưa xong/Đã xong, vuốt để xóa.
- **Tự nhắc nhở khi tới giờ** (báo thức hệ thống – vẫn nhắc khi đã tắt app và sau khi khởi động lại máy):
  - Nhắc từng lịch: đúng giờ, trước 5/10/15/30 phút, 1–2 giờ hoặc 1 ngày.
  - Nhắc **mỗi ngày** vào giờ bạn chọn (tóm tắt lịch & việc chưa xong).
  - Nhắc việc chưa xong **sau mỗi X giờ** (0,5 – 12 giờ) trong khung giờ bạn chọn.
  - Màn hình *Nhắc nhở* có trạng thái quyền + nút thử thông báo ngay / sau 10 giây.

## Lấy file APK để cài lên điện thoại

Mỗi lần push, GitHub Actions tự test và build APK:

1. Vào tab **Actions** của repo → chọn lần chạy **Build APK** mới nhất (dấu ✓ xanh).
2. Tải **MochiPlanner-apk** ở mục *Artifacts*, giải nén ra `MochiPlanner.apk`.
3. Chép sang điện thoại, mở file và cho phép “Cài đặt từ nguồn không xác định”.
4. Lần đầu mở app: cho phép **Thông báo**. Máy Xiaomi/Oppo/Vivo/Huawei/Samsung: bật “Tự khởi động” và đặt Pin “Không hạn chế” để báo đúng giờ.

Có thể tạo Release kèm APK bằng cách push tag, ví dụ `git tag v1.0.0 && git push origin v1.0.0`.

> APK được ký bằng khóa cố định `android/app/mochi-sideload.jks` (để các bản sau cài đè lên bản trước được).
> Khóa này nằm trong repo nên **chỉ dùng cho cài đặt cá nhân**; muốn phát hành lên Google Play hãy tạo khóa riêng.

## Tự build trên máy

Cần [Flutter](https://docs.flutter.dev/get-started/install) (3.47+) và Android SDK.

```bash
flutter pub get
flutter test
flutter build apk --release      # → build/app/outputs/flutter-apk/app-release.apk
flutter run                       # chạy thử trên máy/giả lập đang kết nối
```

## Cấu trúc

```
lib/main.dart               khởi động, thanh điều hướng 3 tab
lib/models.dart             Event / Todo / Settings, quy tắc lặp lịch
lib/store.dart              lưu trữ (shared_preferences) + hẹn lại nhắc nhở mỗi khi dữ liệu đổi
lib/reminder_planner.dart   tính danh sách thông báo cần hẹn giờ (thuần Dart, có test)
lib/notifications.dart      hẹn giờ thông báo bằng báo thức hệ thống Android
lib/ui/                     các màn hình: lịch (tháng/tuần/năm), todo, nhắc nhở, thêm/sửa lịch
test/                       test logic nhắc nhở & giao diện
desktop/                    bản desktop cũ viết bằng Python + PySide6 (không còn dùng cho Android)
```

## Lưu ý về nhắc nhở

Android hẹn sẵn thông báo cho **31 ngày tới** (lịch), **14 ngày** (nhắc mỗi ngày) và **7 ngày** (nhắc việc chưa xong). Mỗi lần mở app hoặc thay đổi dữ liệu, danh sách được tính lại. Nếu không mở app quá lâu, các nhắc nhở định kỳ có thể hết hạn hẹn trước; chỉ cần mở lại app là tiếp tục.
