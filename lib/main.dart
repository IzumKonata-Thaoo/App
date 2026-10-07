import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'notifications.dart';
import 'store.dart';
import 'theme.dart';
import 'ui/calendar_tab.dart';
import 'ui/reminder_tab.dart';
import 'ui/todo_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  final _calendar = GlobalKey<CalendarTabState>();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        CalendarTab(key: _calendar, store: widget.store),
        TodoTab(store: widget.store),
        ReminderTab(store: widget.store),
      ]),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _calendar.currentState?.addEvent(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm lịch', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Lịch'),
          NavigationDestination(icon: Icon(Icons.checklist_rounded), selectedIcon: Icon(Icons.checklist_rtl_rounded), label: 'Việc cần làm'),
          NavigationDestination(icon: Icon(Icons.notifications_none_rounded), selectedIcon: Icon(Icons.notifications_active_rounded), label: 'Nhắc nhở'),
        ],
      ),
    );
  }
}
