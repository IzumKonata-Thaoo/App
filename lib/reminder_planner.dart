import 'models.dart';

/// Một thông báo sẽ được hẹn giờ trên hệ thống.
class PlannedReminder {
  const PlannedReminder(this.at, this.title, this.body, this.kind);
  final DateTime at;
  final String title;
  final String body;
  final String kind; // event | daily | interval

  @override
  String toString() => '$kind@$at "$title"';
}

String leadText(int m) {
  if (m % 1440 == 0) return '${m ~/ 1440} ngày';
  if (m % 60 == 0) return '${m ~/ 60} giờ';
  return '$m phút';
}

List<Event> _eventsOn(List<Event> events, DateTime d) {
  final r = events.where((e) => e.occursOn(d)).toList();
  r.sort((a, b) => (a.start ?? '').compareTo(b.start ?? ''));
  return r;
}

/// Tính toàn bộ thông báo cần hẹn giờ (thuần Dart, không phụ thuộc Android → dễ kiểm thử).
///
/// - Nhắc từng lịch: theo mốc "nhắc trước" của mỗi lịch trong [eventDays] ngày tới.
/// - Nhắc hằng ngày: đúng giờ người dùng chọn trong [dailyDays] ngày tới, kèm tóm tắt.
/// - Nhắc theo chu kỳ: mỗi N giờ trong khung giờ đã chọn, chỉ khi còn việc chưa xong.
List<PlannedReminder> planReminders({
  required List<Event> events,
  required List<Todo> todos,
  required Settings settings,
  required DateTime now,
  int eventDays = 31,
  int dailyDays = 14,
  int intervalDays = 7,
  int maxTotal = 400,
}) {
  final out = <PlannedReminder>[];
  final today = dateOnly(now);
  final open = todos.where((t) => !t.done).toList()..sort((a, b) => b.prio.compareTo(a.prio));

  // ---- nhắc từng lịch ----
  for (var i = 0; i <= eventDays; i++) {
    final day = today.add(Duration(days: i));
    for (final e in _eventsOn(events, day)) {
      final remind = e.remind;
      if (remind == null) continue;
      final startMin = e.start != null ? hhmmToMin(e.start!) : 8 * 60; // cả ngày: tính từ 08:00
      final startDt = day.add(Duration(minutes: startMin));
      final at = startDt.subtract(Duration(minutes: remind));
      if (!at.isAfter(now)) continue;
      final when = e.start != null ? 'Lúc ${e.start}' : 'Cả ngày';
      final lead = remind == 0 ? 'bắt đầu ngay bây giờ' : 'còn ${leadText(remind)}';
      final dayText = remind >= 1440 ? ' (${two(day.day)}/${two(day.month)})' : '';
      out.add(PlannedReminder(
        at,
        '⏰ ${e.title}',
        '$when$dayText · $lead${e.note.isNotEmpty ? '\n📝 ${e.note}' : ''}',
        'event',
      ));
    }
  }

  // ---- nhắc mỗi ngày ----
  if (settings.dailyOn) {
    final m = hhmmToMin(settings.dailyTime);
    for (var i = 0; i < dailyDays; i++) {
      final day = today.add(Duration(days: i));
      final at = day.add(Duration(minutes: m));
      if (!at.isAfter(now)) continue;
      final evs = _eventsOn(events, day);
      final lines = <String>[
        'Hôm nay bạn có ${evs.length} lịch và ${open.length} việc chưa xong.',
        for (final e in evs.take(3)) '• ${e.start ?? 'Cả ngày'} ${e.title}',
        for (final t in open.take(3)) '☐ ${t.text}',
      ];
      out.add(PlannedReminder(at, 'Nhắc nhở hằng ngày 🌸', lines.join('\n'), 'daily'));
    }
  }

  // ---- nhắc mỗi N giờ ----
  if (settings.intervalOn && open.isNotEmpty && settings.intervalHours > 0) {
    final from = hhmmToMin(settings.intervalFrom);
    final to = hhmmToMin(settings.intervalTo);
    final step = (settings.intervalHours * 60).round().clamp(1, 24 * 60);
    final list = open.take(3).map((t) => '• ${t.text}').join('\n');
    final more = open.length > 3 ? '\n…và ${open.length - 3} việc nữa' : '';
    for (var i = 0; i < intervalDays; i++) {
      final day = today.add(Duration(days: i));
      for (var t = from; t <= to; t += step) {
        final at = day.add(Duration(minutes: t));
        if (!at.isAfter(now)) continue;
        out.add(PlannedReminder(at, 'Còn ${open.length} việc chưa xong 📝', '$list$more', 'interval'));
      }
    }
  }

  out.sort((a, b) => a.at.compareTo(b.at));
  return out.length > maxTotal ? out.sublist(0, maxTotal) : out;
}
