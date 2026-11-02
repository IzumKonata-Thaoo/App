import 'models.dart';

/// Một thông báo sẽ được hẹn giờ trên hệ thống.
class PlannedReminder {
  const PlannedReminder(
    this.at,
    this.title,
    this.body,
    this.kind, {
    this.color = 'pink',
    this.tile = const ('', '', ''),
    this.lines = const [],
    this.subText,
    this.ongoingFor,
  });
  final DateTime at;
  final String title;
  final String body;
  final String kind; // event | routine | daily | interval
  final String color; // khóa bảng màu pastel
  final (String, String, String) tile; // ô 3D trong thông báo: (dòng trên, chữ lớn, dòng dưới)
  final List<String> lines; // kiểu "hộp thư" cho tóm tắt
  final String? subText;
  final Duration? ongoingFor; // giữ trên màn hình khóa trong khoảng này

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
String greetingFor(int hour) => hour < 11
    ? 'Chào buổi sáng'
    : hour < 14
    ? 'Chào buổi trưa'
    : hour < 18
    ? 'Chào buổi chiều'
    : 'Chào buổi tối';

(String, String, String) leadTile(int m) {
  if (m == 0) return ('', 'NGAY', 'BÂY GIỜ');
  if (m % 1440 == 0) return ('SAU', '${m ~/ 1440}', 'NGÀY');
  if (m % 60 == 0) return ('SAU', '${m ~/ 60}', 'GIỜ');
  return ('SAU', '$m', 'PHÚT');
}

List<PlannedReminder> planReminders({
  required List<Event> events,
  required List<Todo> todos,
  List<RoutineBlock> routines = const [],
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
      final range = e.start != null && e.end != null ? '${e.start} – ${e.end}' : when;
      out.add(
        PlannedReminder(
          at,
          e.title,
          '$range$dayText · $lead${e.note.isNotEmpty ? '\n${e.note}' : ''}',
          'event',
          color: e.color,
          tile: leadTile(remind),
          subText: e.repeat == Repeat.none ? 'Lịch' : 'Lịch lặp lại',
        ),
      );
    }
  }

  // ---- lịch cố định ----
  for (var i = 0; i <= eventDays; i++) {
    final day = today.add(Duration(days: i));
    final blocks = routines.where((b) => b.occursOn(day)).toList()..sort((a, b) => a.start.compareTo(b.start));
    for (final b in blocks) {
      if (!b.remind && !b.lockScreen) continue;
      final (s, e) = b.span;
      final startDt = day.add(Duration(minutes: s));
      final endDt = day.add(Duration(minutes: e));
      var at = startDt;
      if (!at.isAfter(now)) {
        // Khung giờ đang diễn ra và được ghim màn hình khóa → hiện ngay.
        if (!(b.lockScreen && now.isBefore(endDt))) continue;
        at = now.add(const Duration(seconds: 3));
      }
      out.add(
        PlannedReminder(
          at,
          b.title,
          '${b.start} – ${b.end} · ${describeDays(b.days)}',
          'routine',
          color: b.color,
          tile: ('BẮT ĐẦU', b.start, weekdayShortVi[day.weekday - 1]),
          subText: 'Lịch cố định',
          ongoingFor: b.lockScreen ? endDt.difference(at) : null,
        ),
      );
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
      final blocks = routines.where((b) => b.occursOn(day)).toList()..sort((a, b) => a.start.compareTo(b.start));
      final items = <(String, String)>[for (final e in evs) (e.start ?? 'Cả ngày', e.title), for (final b in blocks) (b.start, b.title)]
        ..sort((a, b) => a.$1.compareTo(b.$1));
      final summary = 'Hôm nay bạn có ${evs.length} lịch, ${blocks.length} khung giờ cố định và ${open.length} việc chưa xong.';
      final lines = [
        for (final it in items.take(5)) '${it.$1}   ${it.$2}',
        if (open.isNotEmpty) 'Việc: ${open.take(2).map((t) => t.text).join(', ')}',
      ];
      out.add(
        PlannedReminder(
          at,
          greetingFor(m ~/ 60),
          [summary, ...lines].join('\n'),
          'daily',
          color: 'yellow',
          tile: (weekdayShortVi[day.weekday - 1], '${day.day}', 'TH ${day.month}'),
          lines: lines,
          subText: summary,
        ),
      );
    }
  }

  // ---- nhắc mỗi N giờ ----
  if (settings.intervalOn && open.isNotEmpty && settings.intervalHours > 0) {
    final from = hhmmToMin(settings.intervalFrom);
    final to = hhmmToMin(settings.intervalTo);
    final step = (settings.intervalHours * 60).round().clamp(1, 24 * 60);
    final list = open.take(3).map((t) => t.text).join(' · ');
    final more = open.length > 3 ? ' …và ${open.length - 3} việc nữa' : '';
    for (var i = 0; i < intervalDays; i++) {
      final day = today.add(Duration(days: i));
      for (var t = from; t <= to; t += step) {
        final at = day.add(Duration(minutes: t));
        if (!at.isAfter(now)) continue;
        out.add(
          PlannedReminder(
            at,
            'Còn ${open.length} việc chưa xong',
            '$list$more',
            'interval',
            color: 'lavender',
            tile: ('CÒN', '${open.length}', 'VIỆC'),
            subText: 'Nhắc mỗi ${settings.intervalHours % 1 == 0 ? settings.intervalHours.round() : settings.intervalHours} giờ',
          ),
        );
      }
    }
  }

  out.sort((a, b) => a.at.compareTo(b.at));
  return out.length > maxTotal ? out.sublist(0, maxTotal) : out;
}
