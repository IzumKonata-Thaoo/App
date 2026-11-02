import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_planner/main.dart';
import 'package:mochi_planner/store.dart';
import 'package:mochi_planner/ui/clay.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder byLabel(String label) =>
    find.byWidgetPredicate((w) => (w is Pressable && w.label == label) || (w is ClaySwitch && w.label == label));

void main() {
  late int scheduled;

  Future<AppStore> pumpApp(WidgetTester tester) async {
    // Tắt hoạt ảnh lặp vô hạn để pumpAndSettle dừng được.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    scheduled = 0;
    final store = await AppStore.load(scheduler: (_) async => scheduled++);
    await tester.pumpWidget(MochiApp(store: store, setupNotifications: false));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('lần đầu mở app có sẵn lịch cố định mẫu và chuyển Tháng/Tuần/Năm', (tester) async {
    final store = await pumpApp(tester);
    expect(store.routines, isNotEmpty);
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

  testWidgets('nút + → thêm lịch có nhắc nhở → được hẹn giờ', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(byLabel('Thêm mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lịch').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Học tiếng Nhật');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(store.events.single.title, 'Học tiếng Nhật');
    expect(store.events.single.remind, 10);
    expect(scheduled, greaterThan(0));
    expect(find.text('Học tiếng Nhật'), findsWidgets);
  });

  testWidgets('todo-list: thêm, tick hoàn thành, xóa', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Việc'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Mua sữa');
    await tester.tap(byLabel('Thêm việc'));
    await tester.pumpAndSettle();
    expect(store.todos.single.text, 'Mua sữa');
    expect(find.text('Còn 1 việc chưa xong'), findsOneWidget);

    await tester.tap(find.byType(ClayCheck));
    await tester.pumpAndSettle();
    expect(store.todos.single.done, isTrue);
    expect(find.text('Xong hết rồi, giỏi quá!'), findsOneWidget);

    await tester.drag(find.text('Việc cần làm').first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa các việc đã xong'));
    await tester.pumpAndSettle();
    expect(store.todos, isEmpty);
  });

  testWidgets('lịch cố định: thêm khung giờ mới', (tester) async {
    final store = await pumpApp(tester);
    final before = store.routines.length;
    await tester.tap(find.text('Cố định'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch cố định'), findsOneWidget);
    await tester.tap(byLabel('Thêm khung giờ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Thiền buổi tối');
    await tester.tap(find.text('Lưu khung giờ'));
    await tester.pumpAndSettle();
    expect(store.routines.length, before + 1);
    final b = store.routines.last;
    expect(b.title, 'Thiền buổi tối');
    expect(b.days, contains(DateTime.now().weekday));
  });

  testWidgets('nhắc nhở: bật nhắc định kỳ và ghim ghi chú màn hình khóa', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Nhắc nhở').first);
    await tester.pumpAndSettle();
    expect(store.settings.intervalOn, isFalse);
    await tester.scrollUntilVisible(byLabel('Nhắc việc chưa xong'), 200, scrollable: find.byType(Scrollable).last);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(byLabel('Nhắc việc chưa xong'));
    await tester.pumpAndSettle();
    expect(store.settings.intervalOn, isTrue);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Gọi mẹ lúc 20:00');
    await tester.tap(byLabel('Ghim ghi chú lên màn hình khóa'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(store.settings.pinnedOn, isTrue);
    expect(store.settings.pinnedNote, 'Gọi mẹ lúc 20:00');
    expect(scheduled, greaterThan(0));
  });
}
