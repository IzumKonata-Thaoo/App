import 'dart:math';

String two(int n) => n.toString().padLeft(2, '0');

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

DateTime parseIso(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

int hhmmToMin(String s) {
  final p = s.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String minToHhmm(int m) {
  m = m.clamp(0, 24 * 60 - 1);
  return '${two(m ~/ 60)}:${two(m % 60)}';
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime addMonths(DateTime d, int n) {
  final idx = d.year * 12 + d.month - 1 + n;
  final y = idx ~/ 12, m = idx % 12 + 1;
  return DateTime(y, m, min(d.day, daysInMonth(y, m)));
}

final _rng = Random();
String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rng.nextInt(1 << 20).toRadixString(36)}';

enum Repeat {
  none('Không lặp'),
  daily('Hằng ngày'),
  weekly('Hằng tuần'),
  monthly('Hằng tháng'),
  yearly('Hằng năm');

  const Repeat(this.label);
  final String label;
}

/// Các mốc nhắc trước (phút). `null` = không nhắc.
const remindOptions = <int?, String>{
  null: 'Không nhắc',
  0: 'Đúng giờ',
  5: 'Trước 5 phút',
  10: 'Trước 10 phút',
  15: 'Trước 15 phút',
  30: 'Trước 30 phút',
  60: 'Trước 1 giờ',
  120: 'Trước 2 giờ',
  1440: 'Trước 1 ngày',
};

class Event {
  Event({
    String? id,
    required this.title,
    required this.date,
    this.start,
    this.end,
    this.repeat = Repeat.none,
    this.remind = 10,
    this.color = 'pink',
    this.note = '',
  }) : id = id ?? newId();

  final String id;
  String title;
  String date; // yyyy-MM-dd
  String? start; // HH:mm, null = cả ngày
  String? end;
  Repeat repeat;
  int? remind;
  String color;
  String note;

  DateTime get day => parseIso(date);

  bool occursOn(DateTime d) {
    d = dateOnly(d);
    final first = day;
    if (d.isBefore(first)) return false;
    switch (repeat) {
      case Repeat.none:
        return d == first;
      case Repeat.daily:
        return true;
      case Repeat.weekly:
        return d.weekday == first.weekday;
      case Repeat.monthly:
        return d.day == min(first.day, daysInMonth(d.year, d.month));
      case Repeat.yearly:
        return d.month == first.month && d.day == min(first.day, daysInMonth(d.year, d.month));
    }
  }

  /// (bắt đầu, kết thúc) tính bằng phút; null nếu cả ngày.
  (int, int)? get span {
    if (start == null) return null;
    final s = hhmmToMin(start!);
    var e = end != null ? hhmmToMin(end!) : s + 60;
    if (e <= s) e = s + 60;
    return (s, min(e, 24 * 60));
  }

  Event copy() => Event(
      id: id, title: title, date: date, start: start, end: end, repeat: repeat, remind: remind, color: color, note: note);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'start': start,
        'end': end,
        'repeat': repeat.name,
        'remind': remind,
        'color': color,
        'note': note,
      };

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String?,
        title: j['title'] as String? ?? '',
        date: j['date'] as String,
        start: j['start'] as String?,
        end: j['end'] as String?,
        repeat: Repeat.values.firstWhere((r) => r.name == j['repeat'], orElse: () => Repeat.none),
        remind: j['remind'] as int?,
        color: j['color'] as String? ?? 'pink',
        note: j['note'] as String? ?? '',
      );
}

class Todo {
  Todo({String? id, required this.text, this.done = false, this.due, this.prio = 1}) : id = id ?? newId();

  final String id;
  String text;
  bool done;
  String? due;
  int prio; // 1 thường, 2 quan trọng, 3 gấp

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'done': done, 'due': due, 'prio': prio};

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String?,
        text: j['text'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        due: j['due'] as String?,
        prio: j['prio'] as int? ?? 1,
      );
}

class Settings {
  Settings({
    this.dailyOn = true,
    this.dailyTime = '08:00',
    this.intervalOn = false,
    this.intervalHours = 2.0,
    this.intervalFrom = '08:00',
    this.intervalTo = '22:00',
  });

  bool dailyOn;
  String dailyTime;
  bool intervalOn;
  double intervalHours;
  String intervalFrom;
  String intervalTo;

  Settings copy() => Settings(
      dailyOn: dailyOn,
      dailyTime: dailyTime,
      intervalOn: intervalOn,
      intervalHours: intervalHours,
      intervalFrom: intervalFrom,
      intervalTo: intervalTo);

  Map<String, dynamic> toJson() => {
        'dailyOn': dailyOn,
        'dailyTime': dailyTime,
        'intervalOn': intervalOn,
        'intervalHours': intervalHours,
        'intervalFrom': intervalFrom,
        'intervalTo': intervalTo,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        dailyOn: j['dailyOn'] as bool? ?? true,
        dailyTime: j['dailyTime'] as String? ?? '08:00',
        intervalOn: j['intervalOn'] as bool? ?? false,
        intervalHours: (j['intervalHours'] as num?)?.toDouble() ?? 2.0,
        intervalFrom: j['intervalFrom'] as String? ?? '08:00',
        intervalTo: j['intervalTo'] as String? ?? '22:00',
      );
}
