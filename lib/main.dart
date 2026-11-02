import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'notifications.dart';
import 'store.dart';
import 'theme.dart';
import 'ui/calendar_tab.dart';
import 'ui/clay.dart';
import 'ui/event_editor.dart';
import 'ui/reminder_tab.dart';
import 'ui/routine_editor.dart';
import 'ui/routine_tab.dart';
import 'ui/todo_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: kBg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await NotificationService.instance.init();
  final store = await AppStore.load();
  runApp(MochiApp(store: store));
}

class MochiApp extends StatelessWidget {
  const MochiApp({super.key, required this.store, this.setupNotifications = true});
  final AppStore store;
  final bool setupNotifications;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mochi Planner',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomeShell(store: store, setupNotifications: setupNotifications),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, this.setupNotifications = true});
  final AppStore store;
  final bool setupNotifications;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _adding = false;
  final _calendar = GlobalKey<CalendarTabState>();
  final _todo = GlobalKey<TodoTabState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.setupNotifications) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await NotificationService.instance.requestPermissions();
        await widget.store.reschedule();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Mỗi lần mở lại app, hẹn lại để "cửa sổ" nhắc nhở luôn được kéo dài về phía trước.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.setupNotifications) widget.store.reschedule();
  }

  Future<void> _quickAdd() async {
    setState(() => _adding = true);
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => const _QuickAddSheet(),
    );
    if (!mounted) return;
    setState(() => _adding = false);
    final day = _calendar.currentState?.current;
    switch (choice) {
      case 0:
        openEventEditor(context, widget.store, day: day);
      case 1:
        setState(() => _tab = 1);
        WidgetsBinding.instance.addPostFrameCallback((_) => _todo.currentState?.focusInput());
      case 2:
        openRoutineEditor(context, widget.store, days: {(day ?? DateTime.now()).weekday});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _tab,
              children: [
                CalendarTab(key: _calendar, store: widget.store),
                TodoTab(key: _todo, store: widget.store),
                RoutineTab(store: widget.store),
                ReminderTab(store: widget.store),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14 + bottom,
            child: _NavBar(index: _tab, adding: _adding, onSelect: (i) => setState(() => _tab = i), onAdd: _quickAdd),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.adding, required this.onSelect, required this.onAdd});
  final int index;
  final bool adding;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  static const _items = [(Ic.calendarDays, 'Lịch'), (Ic.squareCheck, 'Việc'), (Ic.repeat, 'Cố định'), (Ic.bellRing, 'Nhắc nhở')];

  Widget _item(int i) {
    final sel = i == index;
    final (icon, label) = _items[i];
    return Expanded(
      child: Semantics(
        button: true,
        selected: sel,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(i),
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  padding: EdgeInsets.symmetric(horizontal: sel ? 14 : 6, vertical: 4),
                  decoration: BoxDecoration(color: sel ? kPrimarySoft : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    scale: sel ? 1.08 : 1,
                    child: Icon(icon, size: 21, color: sel ? kPrimary : kMuted),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: ts(11, w: FontWeight.w700, c: sel ? kPrimary : kMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: Clay(radius: 26, depth: 1.1, child: SizedBox.expand())),
          Row(children: [_item(0), _item(1), const SizedBox(width: 72), _item(2), _item(3)]),
          Positioned(
            top: -26,
            left: 0,
            right: 0,
            child: Center(
              child: Pressable(
                onTap: onAdd,
                label: 'Thêm mới',
                scale: 0.9,
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  turns: adding ? 0.125 : -0.017,
                  child: const Clay(
                    color: kPrimary,
                    tint: kPrimary,
                    radius: 21,
                    depth: 1.2,
                    width: 60,
                    height: 60,
                    child: Icon(Ic.plus, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet();

  @override
  Widget build(BuildContext context) {
    Widget option(int i, IconData icon, String color, String title, String sub) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FadeUp(
        delay: Duration(milliseconds: 60 * i),
        child: Pressable(
          label: title,
          scale: 0.97,
          onTap: () => Navigator.pop(context, i),
          child: Clay(
            radius: 22,
            depth: 0.7,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconTile(icon: icon, color: color, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ts(16, w: FontWeight.w800)),
                      Text(sub, style: ts(12.5, c: kMuted)),
                    ],
                  ),
                ),
                const Icon(Ic.chevronRight, color: kMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: const Color(0xFFE4D3E2), borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Thêm mới', style: ts(20, w: FontWeight.w800)),
            const SizedBox(height: 14),
            option(0, Ic.calendarClock, 'pink', 'Lịch', 'Một sự kiện có ngày giờ, có nhắc trước'),
            option(1, Ic.squareCheck, 'mint', 'Việc cần làm', 'Thêm vào danh sách, có hạn chót'),
            option(2, Ic.repeat, 'lavender', 'Khung giờ cố định', 'Việc lặp lại hằng tuần vào giờ cố định'),
          ],
        ),
      ),
    );
  }
}
