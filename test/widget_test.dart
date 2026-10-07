import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_planner/main.dart';
import 'package:mochi_planner/models.dart';
import 'package:mochi_planner/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<List<Event>> scheduled;

  Future<AppStore> makeStore() async {
    SharedPreferences.setMockInitialValues({});
    scheduled = [];
    return AppStore.load(scheduler: (ev, td, st) async => scheduled.add(ev.map((e) => e.copy()).toList()));
  }

  testWidgets('hiện lịch tháng và chuyển giữa Tháng/Tuần/Năm', (tester) async {
    final store = await makeStore();
    await tester.pumpWidget(MochiApp(store: store, setupNotifications: false));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(find.text('Tháng ${now.month}, ${now.year}'), findsOneWidget);

    await tester.tap(find.text('Tuần'));
    await tester.pumpAndSettle();
    expect(find.text('T2'), findsWidgets);

    await tester.tap(find.text('Năm'));
    await tester.pumpAndSettle();
    expect(find.text('Năm ${now.year}'), findsOneWidget);
    expect(find.text('Tháng 1'), findsOneWidget);
  });

  testWidgets('thêm lịch có nhắc nhở → được đưa vào bộ hẹn giờ', (tester) async {
    final store = await makeStore();
    await tester.pumpWidget(MochiApp(store: store, setupNotifications: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm lịch'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Học tiếng Nhật');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(store.events.length, 1);
    expect(store.events.first.title, 'Học tiếng Nhật');
    expect(store.events.first.remind, 10); // mặc định nhắc trước 10 phút
    expect(scheduled, isNotEmpty);
    expect(scheduled.last.first.title, 'Học tiếng Nhật');
    expect(find.text('Học tiếng Nhật'), findsWidgets);
  });

  testWidgets('todo-list: thêm, tick hoàn thành, xóa', (tester) async {
    final store = await makeStore();
    await tester.pumpWidget(MochiApp(store: store, setupNotifications: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Việc cần làm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Mua sữa');
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pumpAndSettle();
    expect(store.todos.single.text, 'Mua sữa');
    expect(find.text('Đã xong 0/1'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(store.todos.single.done, isTrue);
    expect(find.text('Đã xong 1/1'), findsOneWidget);

    await tester.tap(find.text('Xóa các việc đã xong'));
    await tester.pumpAndSettle();
    expect(store.todos, isEmpty);
  });

  testWidgets('màn hình nhắc nhở bật/tắt cài đặt', (tester) async {
    final store = await makeStore();
    await tester.pumpWidget(MochiApp(store: store, setupNotifications: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhắc nhở').last);
    await tester.pumpAndSettle();
    expect(store.settings.intervalOn, isFalse);
    await tester.tap(find.text('Nhắc việc chưa xong'));
    await tester.pumpAndSettle();
    expect(store.settings.intervalOn, isTrue);
    expect(scheduled, isNotEmpty);
  });
}
