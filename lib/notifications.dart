import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_planner.dart';
import 'store.dart';
import 'theme.dart';

const _channelId = 'mochi_reminders_v2';
const _channelName = 'Nhắc nhở';
const _pinnedChannelId = 'mochi_pinned';
const _pinnedChannelName = 'Ghi chú màn hình khóa';
const _pinnedId = 777000;

const _actAck = 'ack';
const _actSnooze = 'snooze';
const _actOpen = 'open';

/// Bấm nút trên thông báo khi app đang tắt: "Nhắc 5 phút" hẹn lại thông báo đó.
@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse r) => NotificationService.handleAction(r);

/// Hẹn giờ thông báo bằng báo thức hệ thống Android (AlarmManager):
/// vẫn nhắc khi đã tắt app và tự đặt lại sau khi khởi động máy.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _busy = false;
  bool _again = false;
  AppStore? _latest;
  Timer? _debounce;
  Completer<void>? _waiting;
  String? _lastSig; // lịch nhắc đã áp dụng trong phiên này (bỏ qua nếu không đổi)
  final _tiles = <String, Uint8List>{};

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static const _init = InitializationSettings(android: AndroidInitializationSettings('ic_stat_notify'));

  Future<void> init() async {
    // Chỉ dùng thời điểm tuyệt đối (epoch) theo UTC → không cần nạp cơ sở dữ liệu múi giờ (mở app nhanh hơn).
    tz.setLocalLocation(tz.UTC);
    await _plugin.initialize(
      settings: _init,
      onDidReceiveNotificationResponse: handleAction,
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Nhắc lịch, khung giờ cố định, việc cần làm và tóm tắt mỗi ngày',
        importance: Importance.high,
      ),
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _pinnedChannelId,
        _pinnedChannelName,
        description: 'Ghi chú ghim luôn hiện trên màn hình khóa',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
    _ready = true;
  }

  /// Xử lý nút bấm trên thông báo (cả khi app đang mở lẫn đang tắt).
  @pragma('vm:entry-point')
  static Future<void> handleAction(NotificationResponse r) async {
    if (r.actionId != _actSnooze || r.payload == null || r.payload!.isEmpty) return;
    try {
      final p = jsonDecode(r.payload!) as Map<String, dynamic>;
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(settings: _init);
      tz.setLocalLocation(tz.UTC);
      final at = DateTime.now().add(const Duration(minutes: 5));
      final color = palette[p['c']]?.fg ?? kPrimary;
      await plugin.zonedSchedule(
        id: 800000 + Random().nextInt(99999),
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, at.millisecondsSinceEpoch),
        title: p['t'] as String?,
        body: p['b'] as String?,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_notify',
            color: color,
            subText: 'Nhắc lại sau 5 phút',
            visibility: NotificationVisibility.public,
            styleInformation: BigTextStyleInformation(p['b'] as String? ?? ''),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('snooze lỗi: $e');
    }
  }

  /// Xin quyền hiện thông báo (Android 13+) và báo thức chính xác (Android 12).
  Future<void> requestPermissions() async {
    final a = _android;
    if (a == null) return;
    await a.requestNotificationsPermission();
    if (!(await a.canScheduleExactNotifications() ?? true)) {
      await a.requestExactAlarmsPermission();
    }
  }

  Future<bool> notificationsEnabled() async => await _android?.areNotificationsEnabled() ?? false;
  Future<bool> exactAlarmsAllowed() async => await _android?.canScheduleExactNotifications() ?? false;
  Future<void> openSettings() async => _android?.openAppNotificationSettings();
  Future<int> pendingCount() async => (await _plugin.pendingNotificationRequests()).length;

  // ---------------------------------------------------------------- hiển thị
  static String _glyph(String kind) => switch (kind) {
    'routine' => 'repeat',
    'daily' => 'sun',
    'interval' => 'check',
    _ => 'bell',
  };

  /// [live]: thông báo hiện ngay → vẽ ô có chữ; thông báo hẹn giờ → dùng ảnh có sẵn trong app
  /// (plugin lưu mọi thông báo hẹn giờ thành JSON, nhúng ảnh vào sẽ rất nặng và gây giật).
  Future<NotificationDetails> _details(PlannedReminder r, {bool live = false}) async {
    final p = pastel(r.color);
    final tile = live ? await _tile(r.color, r.tile) : null;
    final actions = switch (r.kind) {
      'event' => const [
        AndroidNotificationAction(_actAck, 'Đã biết', cancelNotification: true),
        AndroidNotificationAction(_actSnooze, 'Nhắc 5 phút', cancelNotification: true),
        AndroidNotificationAction(_actOpen, 'Mở lịch', showsUserInterface: true),
      ],
      'interval' => const [
        AndroidNotificationAction(_actOpen, 'Xem danh sách', showsUserInterface: true),
        AndroidNotificationAction(_actAck, 'Để sau', cancelNotification: true),
      ],
      'routine' => const [
        AndroidNotificationAction(_actAck, 'Đã bắt đầu', cancelNotification: true),
        AndroidNotificationAction(_actSnooze, 'Nhắc 5 phút', cancelNotification: true),
      ],
      _ => const <AndroidNotificationAction>[],
    };
    final style = r.lines.isNotEmpty
        ? InboxStyleInformation(r.lines, contentTitle: '<b>${_esc(r.title)}</b>', htmlFormatContentTitle: true, summaryText: r.subText)
        : BigTextStyleInformation(
            _esc(r.body).replaceAll('\n', '<br>'),
            htmlFormatBigText: true,
            contentTitle: '<b>${_esc(r.title)}</b>',
            htmlFormatContentTitle: true,
            summaryText: r.subText,
          );
    final ongoing = r.ongoingFor != null;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        icon: 'ic_stat_notify',
        color: p.fg,
        largeIcon: tile != null
            ? ByteArrayAndroidBitmap(tile)
            : DrawableResourceAndroidBitmap('tile_${palette.containsKey(r.color) ? r.color : 'pink'}_${_glyph(r.kind)}'),
        styleInformation: style,
        subText: r.subText,
        visibility: NotificationVisibility.public,
        ongoing: ongoing,
        autoCancel: !ongoing,
        timeoutAfter: ongoing ? r.ongoingFor!.inMilliseconds : null,
        actions: actions,
      ),
    );
  }

  static String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  /// Ô vuông nổi 3D (như trong thiết kế) vẽ bằng Canvas, dùng làm ảnh lớn của thông báo.
  Future<Uint8List?> _tile(String color, (String, String, String) t) async {
    final key = '$color|${t.$1}|${t.$2}|${t.$3}';
    final cached = _tiles[key];
    if (cached != null) return cached;
    try {
      final p = pastel(color);
      const size = 192.0;
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      final r = RRect.fromRectAndRadius(const Rect.fromLTWH(8, 6, size - 16, size - 18), const Radius.circular(48));
      // bóng đổ
      c.drawRRect(
        r.shift(const Offset(0, 8)),
        Paint()
          ..color = p.fg.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      // thân khối: sáng ở trên, đậm dần xuống dưới
      c.drawRRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            r.outerRect.topCenter,
            r.outerRect.bottomCenter,
            [Color.lerp(p.bg, const Color(0xFFFFFFFF), 0.45)!, p.bg, Color.lerp(p.bg, p.fg, 0.18)!],
            [0, 0.55, 1],
          ),
      );
      // viền sáng phía trên
      c.drawRRect(
        r.deflate(3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..shader = ui.Gradient.linear(r.outerRect.topCenter, r.outerRect.center, [const Color(0xCCFFFFFF), const Color(0x00FFFFFF)]),
      );
      void text(String s, double y, double fs, FontWeight w) {
        if (s.isEmpty) return;
        final pb =
            ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontFamily: kFont, fontSize: fs, fontWeight: w, maxLines: 1))
              ..pushStyle(ui.TextStyle(color: p.fg, letterSpacing: fs < 30 ? 1.5 : -1))
              ..addText(s);
        final para = pb.build()..layout(const ui.ParagraphConstraints(width: size));
        c.drawParagraph(para, Offset(0, y - para.height / 2));
      }

      final big = t.$2;
      final bigSize = big.length <= 2 ? 78.0 : (big.length <= 4 ? 56.0 : 46.0);
      text(t.$1, 44, 22, FontWeight.w800);
      text(big, 96, bigSize, FontWeight.w800);
      text(t.$3, 146, 22, FontWeight.w800);
      final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      _tiles[key] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('vẽ ô thông báo lỗi: $e');
      return null;
    }
  }

  Future<void> showNow(String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id: 999000,
      title: title,
      body: body,
      notificationDetails: await _details(
        PlannedReminder(DateTime.now(), title, body, 'event', color: 'pink', tile: ('', 'NGAY', 'BÂY GIỜ'), subText: 'Thông báo thử'),
        live: true,
      ),
      payload: jsonEncode({'t': title, 'b': body, 'c': 'pink'}),
    );
  }

  /// Hẹn một thông báo thử sau [seconds] giây qua đúng cơ chế báo thức thật.
  Future<void> scheduleTest(int seconds) async {
    if (!_ready) return;
    final r = PlannedReminder(
      DateTime.now().add(Duration(seconds: seconds)),
      'Thông báo thử',
      'Nhắc nhở hẹn giờ hoạt động bình thường!',
      'event',
      color: 'lavender',
      tile: ('SAU', '$seconds', 'GIÂY'),
      subText: 'Thông báo thử',
    );
    await _schedule(999001, r, await exactAlarmsAllowed());
  }

  Future<void> _schedule(int id, PlannedReminder r, bool exact) async {
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, r.at.millisecondsSinceEpoch),
      title: r.title,
      body: r.body,
      payload: jsonEncode({'t': r.title, 'b': r.body, 'c': r.color}),
      notificationDetails: await _details(r),
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Ghi chú ghim: một thông báo luôn hiện (không tự mất) trên màn hình khóa.
  Future<void> updatePinned(AppStore s) async {
    if (!_ready) return;
    final note = s.settings.pinnedNote.trim();
    if (!s.settings.pinnedOn || note.isEmpty) {
      await _plugin.cancel(id: _pinnedId);
      return;
    }
    await _plugin.show(
      id: _pinnedId,
      title: 'Ghi chú ghim',
      body: note,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _pinnedChannelId,
          _pinnedChannelName,
          importance: Importance.low,
          priority: Priority.low,
          icon: 'ic_stat_notify',
          color: pastel('yellow').fg,
          largeIcon: const DrawableResourceAndroidBitmap('tile_yellow_pin'),
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: false,
          silent: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.status,
          styleInformation: BigTextStyleInformation(_esc(note).replaceAll('\n', '<br>'), htmlFormatBigText: true),
        ),
      ),
    );
  }

  /// Hẹn lại toàn bộ nhắc nhở theo dữ liệu hiện tại.
  /// Các thay đổi liên tiếp (tick việc, gõ ghi chú…) được gộp lại sau 0,8 giây, và nếu
  /// lịch nhắc không đổi thì bỏ qua — tránh làm việc nặng trên luồng giao diện.
  Future<void> reschedule(AppStore store) {
    if (!_ready) return Future.value();
    _latest = store;
    final waiting = _waiting ??= Completer<void>();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _run);
    return waiting.future;
  }

  Future<void> _run() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    final done = _waiting;
    _waiting = null;
    try {
      do {
        _again = false;
        final s = _latest!;
        final plan = planReminders(
          events: s.events.map((e) => e.copy()).toList(),
          todos: List.of(s.todos),
          routines: s.routines.map((r) => r.copy()).toList(),
          settings: s.settings.copy(),
          now: DateTime.now(),
        );
        final sig = [
          for (final r in plan) '${r.at.millisecondsSinceEpoch}|${r.kind}|${r.color}|${r.title}|${r.body}|${r.ongoingFor?.inSeconds}',
          'pin:${s.settings.pinnedOn}:${s.settings.pinnedNote}',
        ].join('\n');
        if (sig == _lastSig) continue;
        await _plugin.cancelAllPendingNotifications();
        final exact = await exactAlarmsAllowed();
        var id = 1;
        for (final r in plan) {
          await _schedule(id++, r, exact);
        }
        await updatePinned(s);
        _lastSig = sig;
      } while (_again);
    } catch (e, st) {
      debugPrint('reschedule lỗi: $e\n$st');
    } finally {
      _busy = false;
      done?.complete();
    }
  }
}
