import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_planner/layout.dart';
import 'package:mochi_planner/models.dart';
import 'package:mochi_planner/reminder_planner.dart';

void main() {
  final now = DateTime(2026, 10, 7, 8, 0); // Thứ Tư

  List<PlannedReminder> plan({
    List<Event> events = const [],
    List<Todo> todos = const [],
    Settings? settings,
    DateTime? at,
  }) =>
      planReminders(
        events: events,
        todos: todos,
        settings: settings ?? Settings(dailyOn: false),
        now: at ?? now,
      );

  group('nhắc từng lịch', () {
    test('nhắc trước đúng số phút', () {
      final r = plan(events: [Event(title: 'Họp', date: '2026-10-07', start: '09:00', remind: 15)]);
      expect(r.length, 1);
      expect(r.single.at, DateTime(2026, 10, 7, 8, 45));
      expect(r.single.title, contains('Họp'));
      expect(r.single.body, contains('còn 15 phút'));
    });

    test('nhắc đúng giờ', () {
      final r = plan(events: [Event(title: 'A', date: '2026-10-07', start: '09:00', remind: 0)]);
      expect(r.single.at, DateTime(2026, 10, 7, 9, 0));
      expect(r.single.body, contains('bắt đầu ngay bây giờ'));
    });

    test('remind = null thì không nhắc; mốc đã qua thì bỏ', () {
      expect(plan(events: [Event(title: 'A', date: '2026-10-07', start: '09:00', remind: null)]), isEmpty);
      expect(plan(events: [Event(title: 'A', date: '2026-10-07', start: '08:05', remind: 10)]), isEmpty);
    });

    test('lịch cả ngày tính từ 08:00, nhắc trước 1 ngày', () {
      final r = plan(events: [Event(title: 'Sinh nhật', date: '2026-10-09', remind: 1440)]);
      expect(r.single.at, DateTime(2026, 10, 8, 8, 0));
    });

    test('lịch lặp hằng tuần sinh nhiều lần nhắc', () {
      final r = plan(events: [Event(title: 'Gym', date: '2026-10-01', start: '18:00', repeat: Repeat.weekly, remind: 10)]);
      // 7/10 là Thứ Tư; lịch gốc thứ Năm → 8/10, 15/10, 22/10, 29/10, 5/11
      expect(r.map((e) => e.at.day).take(3), [8, 15, 22]);
      expect(r.length, greaterThanOrEqualTo(4));
    });
  });

  group('nhắc mỗi ngày', () {
    test('mỗi ngày đúng giờ chọn, kèm tóm tắt', () {
      final r = plan(
        settings: Settings(dailyOn: true, dailyTime: '07:30'),
        at: DateTime(2026, 10, 7, 7, 0),
        events: [Event(title: 'Họp', date: '2026-10-07', start: '09:00', remind: null)],
        todos: [Todo(text: 'Mua sữa')],
      );
      final daily = r.where((e) => e.kind == 'daily').toList();
      expect(daily.length, 14);
      expect(daily.first.at, DateTime(2026, 10, 7, 7, 30));
      expect(daily.first.body, contains('1 lịch và 1 việc chưa xong'));
      expect(daily.first.body, contains('09:00 Họp'));
    });

    test('giờ hôm nay đã qua thì bắt đầu từ ngày mai', () {
      final r = plan(settings: Settings(dailyOn: true, dailyTime: '07:30'));
      expect(r.first.at, DateTime(2026, 10, 8, 7, 30));
    });
  });

  group('nhắc sau mỗi X giờ', () {
    final s = Settings(dailyOn: false, intervalOn: true, intervalHours: 2, intervalFrom: '08:00', intervalTo: '22:00');

    test('chia theo bước giờ trong khung giờ', () {
      final r = plan(settings: s, todos: [Todo(text: 'A'), Todo(text: 'B')], at: DateTime(2026, 10, 7, 7, 0));
      final today = r.where((e) => e.at.day == 7).map((e) => e.at.hour).toList();
      expect(today, [8, 10, 12, 14, 16, 18, 20, 22]);
      expect(r.first.title, 'Còn 2 việc chưa xong 📝');
    });

    test('chỉ nhắc các mốc còn ở tương lai', () {
      final r = plan(settings: s, todos: [Todo(text: 'A')], at: DateTime(2026, 10, 7, 13, 0));
      expect(r.first.at, DateTime(2026, 10, 7, 14, 0));
    });

    test('không nhắc khi mọi việc đã xong', () {
      expect(plan(settings: s, todos: [Todo(text: 'A', done: true)]), isEmpty);
    });

    test('bước 1.5 giờ', () {
      final r = plan(
        settings: Settings(dailyOn: false, intervalOn: true, intervalHours: 1.5, intervalFrom: '08:00', intervalTo: '12:00'),
        todos: [Todo(text: 'A')],
        at: DateTime(2026, 10, 7, 7, 0),
      );
      expect(r.where((e) => e.at.day == 7).map((e) => '${e.at.hour}:${e.at.minute}'), ['8:0', '9:30', '11:0']);
    });
  });

  test('giới hạn tổng số thông báo và sắp theo thời gian', () {
    final r = planReminders(
      events: [Event(title: 'Mỗi ngày', date: '2026-10-01', start: '09:00', repeat: Repeat.daily, remind: 0)],
      todos: [Todo(text: 'A')],
      settings: Settings(dailyOn: true, intervalOn: true, intervalHours: 0.5),
      now: now,
      maxTotal: 50,
    );
    expect(r.length, 50);
    for (var i = 1; i < r.length; i++) {
      expect(r[i].at.isBefore(r[i - 1].at), isFalse);
    }
  });

  group('quy tắc lặp', () {
    test('hằng tháng ngày 31 rơi vào ngày cuối tháng ngắn', () {
      final e = Event(title: 'x', date: '2026-01-31', repeat: Repeat.monthly);
      expect(e.occursOn(DateTime(2026, 2, 28)), isTrue);
      expect(e.occursOn(DateTime(2026, 2, 27)), isFalse);
      expect(e.occursOn(DateTime(2026, 3, 31)), isTrue);
    });
    test('hằng năm 29/2 rơi vào 28/2 năm thường; không xảy ra trước ngày gốc', () {
      final e = Event(title: 'x', date: '2024-02-29', repeat: Repeat.yearly);
      expect(e.occursOn(DateTime(2026, 2, 28)), isTrue);
      expect(e.occursOn(DateTime(2028, 2, 29)), isTrue);
      expect(e.occursOn(DateTime(2023, 2, 28)), isFalse);
    });
    test('addMonths giữ ngày hợp lệ', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2026, 1, 15), -1), DateTime(2025, 12, 15));
    });
    test('JSON khứ hồi', () {
      final e = Event(title: 'x', date: '2026-10-07', start: '09:00', end: '10:00', repeat: Repeat.weekly, remind: 30, color: 'mint', note: 'n');
      final b = Event.fromJson(e.toJson());
      expect([b.title, b.start, b.end, b.repeat, b.remind, b.color, b.note], ['x', '09:00', '10:00', Repeat.weekly, 30, 'mint', 'n']);
    });
  });

  test('layoutColumns chia cột sự kiện chồng nhau', () {
    final p = layoutColumns<String>([(540, 600, 'a'), (570, 630, 'b'), (700, 760, 'c')]);
    final m = {for (final x in p) x.item: x};
    expect(m['a']!.cols, 2);
    expect(m['b']!.cols, 2);
    expect(m['a']!.col != m['b']!.col, isTrue);
    expect(m['c']!.cols, 1);
  });
}
