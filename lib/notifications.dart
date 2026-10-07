import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'reminder_planner.dart';

/// Hẹn giờ thông báo bằng báo thức hệ thống Android (AlarmManager):
/// vẫn nhắc khi đã tắt app và tự đặt lại sau khi khởi động máy.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _channelId = 'mochi_reminders';
  static const _channelName = 'Nhắc nhở';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _busy = false;
  bool _again = false;
  Future<void>? _running;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Nhắc lịch, việc cần làm và tóm tắt mỗi ngày',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_notify',
      color: Color(0xFFFF8FBA),
      styleInformation: BigTextStyleInformation(''),
    ),
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.UTC); // chỉ dùng thời điểm tuyệt đối (epoch), không cần múi giờ
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_notify')),
    );
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Nhắc lịch, việc cần làm và tóm tắt mỗi ngày',
      importance: Importance.high,
    ));
    _ready = true;
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

  Future<void> showNow(String title, String body) async {
    if (!_ready) return;
    await _plugin.show(id: 999000, title: title, body: body, notificationDetails: _details);
  }

  /// Hẹn một thông báo thử sau [seconds] giây qua đúng cơ chế báo thức thật.
  Future<void> scheduleTest(int seconds) async {
    if (!_ready) return;
    await _schedule(999001, DateTime.now().add(Duration(seconds: seconds)), 'Thông báo thử 🌸',
        'Nhắc nhở hẹn giờ hoạt động bình thường!');
  }

  Future<void> _schedule(int id, DateTime at, String title, String body) async {
    final when = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, at.millisecondsSinceEpoch);
    final exact = await exactAlarmsAllowed();
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: when,
      title: title,
      body: body,
      notificationDetails: _details,
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Hẹn lại toàn bộ nhắc nhở theo dữ liệu hiện tại. Gọi liên tiếp sẽ được gộp lại.
  Future<void> reschedule(List<Event> events, List<Todo> todos, Settings settings) {
    if (!_ready) return Future.value();
    _latest = (events.map((e) => e.copy()).toList(), List.of(todos), settings.copy());
    if (_busy) {
      _again = true;
      return _running ?? Future.value();
    }
    _busy = true;
    _running = () async {
      try {
        do {
          _again = false;
          final (ev, td, st) = _latest!;
          await _apply(planReminders(events: ev, todos: td, settings: st, now: DateTime.now()));
        } while (_again);
      } catch (e, s) {
        debugPrint('reschedule lỗi: $e\n$s');
      } finally {
        _busy = false;
      }
    }();
    return _running!;
  }

  (List<Event>, List<Todo>, Settings)? _latest;

  Future<void> _apply(List<PlannedReminder> plan) async {
    await _plugin.cancelAllPendingNotifications();
    var id = 1;
    for (final r in plan) {
      await _schedule(id++, r.at, r.title, r.body);
    }
  }

  Future<int> pendingCount() async => (await _plugin.pendingNotificationRequests()).length;
}
