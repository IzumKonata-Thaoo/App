import 'package:flutter/material.dart';

import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';

class ReminderTab extends StatefulWidget {
  const ReminderTab({super.key, required this.store});
  final AppStore store;

  @override
  State<ReminderTab> createState() => _ReminderTabState();
}

class _ReminderTabState extends State<ReminderTab> with WidgetsBindingObserver {
  bool _notif = false;
  bool _exact = false;
  int _pending = 0; // ignore: prefer_final_fields

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final n = NotificationService.instance;
      final (notif, exact, pending) = await (n.notificationsEnabled(), n.exactAlarmsAllowed(), n.pendingCount()).wait;
      if (mounted) {
        setState(() {
          _notif = notif;
          _exact = exact;
          _pending = pending;
        });
      }
    } catch (_) {
      // chạy ngoài Android (ví dụ khi kiểm thử): bỏ qua
    }
  }

  Future<void> _pickTime(String current, ValueChanged<String> onPicked) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hhmmToMin(current) ~/ 60, minute: hhmmToMin(current) % 60),
      helpText: 'Chọn giờ',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t != null) onPicked('${two(t.hour)}:${two(t.minute)}');
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final s = widget.store.settings;
          final open = widget.store.openTodos.length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Text('Mochi Planner 🌸', style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w800)),
              const Text('Nhắc nhở', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _statusCard(),
              const SizedBox(height: 12),
              Card(
                child: Column(children: [
                  SwitchListTile(
                    secondary: const Text('☀️', style: TextStyle(fontSize: 22)),
                    title: const Text('Nhắc mỗi ngày', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Tóm tắt lịch & việc chưa xong trong ngày'),
                    value: s.dailyOn,
                    onChanged: (v) => widget.store.updateSettings((x) => x.dailyOn = v),
                  ),
                  ListTile(
                    enabled: s.dailyOn,
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Giờ nhắc'),
                    trailing: Text(s.dailyTime, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: s.dailyOn ? kAccent : kMuted)),
                    onTap: () => _pickTime(s.dailyTime, (v) => widget.store.updateSettings((x) => x.dailyTime = v)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(children: [
                  SwitchListTile(
                    secondary: const Text('⏳', style: TextStyle(fontSize: 22)),
                    title: const Text('Nhắc việc chưa xong', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(s.intervalOn ? 'Sau mỗi ${_hours(s.intervalHours)}, đang còn $open việc' : 'Nhắc lặp lại sau mỗi X giờ'),
                    value: s.intervalOn,
                    onChanged: (v) => widget.store.updateSettings((x) => x.intervalOn = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      const Text('Mỗi', style: TextStyle(fontWeight: FontWeight.w700)),
                      Expanded(
                        child: Slider(
                          value: s.intervalHours.clamp(0.5, 12),
                          min: 0.5,
                          max: 12,
                          divisions: 23,
                          label: _hours(s.intervalHours),
                          onChanged: s.intervalOn ? (v) => widget.store.updateSettings((x) => x.intervalHours = v) : null,
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(_hours(s.intervalHours),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontWeight: FontWeight.w900, color: s.intervalOn ? kAccent : kMuted)),
                      ),
                    ]),
                  ),
                  Row(children: [
                    Expanded(
                      child: ListTile(
                        enabled: s.intervalOn,
                        title: const Text('Từ'),
                        trailing: Text(s.intervalFrom, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: s.intervalOn ? kAccent : kMuted)),
                        onTap: () => _pickTime(s.intervalFrom, (v) => widget.store.updateSettings((x) => x.intervalFrom = v)),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        enabled: s.intervalOn,
                        title: const Text('Đến'),
                        trailing: Text(s.intervalTo, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: s.intervalOn ? kAccent : kMuted)),
                        onTap: () => _pickTime(s.intervalTo, (v) => widget.store.updateSettings((x) => x.intervalTo = v)),
                      ),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('🔔 Nhắc từng lịch', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Khi thêm hoặc sửa lịch, chọn mục “Nhắc nhở” (đúng giờ, trước 5 phút … 1 ngày). Máy sẽ tự báo khi tới giờ, kể cả lúc đã tắt app.',
                        style: TextStyle(color: kMuted, fontSize: 13)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('🧪 Kiểm tra thông báo', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 8, children: [
                      OutlinedButton(
                        onPressed: () async {
                          await NotificationService.instance.showNow('Thử nhắc nhở 🌸', 'Thông báo hiển thị bình thường!');
                          _refresh();
                        },
                        child: const Text('Hiện ngay'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await NotificationService.instance.scheduleTest(10);
                          _toast('Đã hẹn! Hãy thoát app, 10 giây nữa sẽ có thông báo.');
                          _refresh();
                        },
                        child: const Text('Hẹn sau 10 giây'),
                      ),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFFFFBEA),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '💡 Nếu máy Xiaomi, Oppo, Vivo, Huawei, Samsung… không báo đúng giờ: vào Cài đặt › Ứng dụng › Mochi Planner, '
                    'bật “Tự khởi động” và đặt Pin ở mức “Không hạn chế”.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8A7410)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _hours(double h) => h == h.roundToDouble() ? '${h.round()} giờ' : '${h.toStringAsFixed(1)} giờ';

  Widget _statusCard() {
    final ok = _notif && _exact;
    return Card(
      color: ok ? const Color(0xFFEAFBF0) : const Color(0xFFFFF0F4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ok ? '✅ Nhắc nhở đang hoạt động' : '⚠️ Cần cấp quyền để nhắc đúng giờ',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          _line('Hiện thông báo', _notif),
          _line('Báo thức chính xác', _exact),
          Text('Đang hẹn sẵn $_pending thông báo', style: const TextStyle(color: kMuted, fontSize: 12)),
          if (!ok) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 10, children: [
              FilledButton(
                onPressed: () async {
                  await NotificationService.instance.requestPermissions();
                  await widget.store.reschedule();
                  _refresh();
                },
                child: const Text('Cấp quyền'),
              ),
              OutlinedButton(
                onPressed: () => NotificationService.instance.openSettings(),
                child: const Text('Mở cài đặt'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _line(String label, bool on) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          Icon(on ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: on ? const Color(0xFF2E7D57) : kDanger),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ]),
      );
}
