import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'clay.dart';
import 'routine_editor.dart';

class ReminderTab extends StatefulWidget {
  const ReminderTab({super.key, required this.store});
  final AppStore store;

  @override
  State<ReminderTab> createState() => _ReminderTabState();
}

class _ReminderTabState extends State<ReminderTab> with WidgetsBindingObserver {
  bool _notif = false;
  bool _exact = false;
  int _pending = 0;
  late final TextEditingController _note = TextEditingController(text: widget.store.settings.pinnedNote);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _note.dispose();
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

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  void _onNote(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => widget.store.updateSettings((x) => x.pinnedNote = v));
  }

  Widget _card({required Widget child, Duration delay = Duration.zero}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: FadeUp(
      delay: delay,
      child: Clay(radius: 24, depth: 0.7, padding: const EdgeInsets.all(16), child: child),
    ),
  );

  Widget _head(IconData icon, String color, String title, String sub, {Widget? trailing}) => Row(
    children: [
      IconTile(icon: icon, color: color),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: ts(15, w: FontWeight.w800)),
            Text(sub, style: ts(12.5, c: kMuted)),
          ],
        ),
      ),
      ?trailing,
    ],
  );

  Widget _timeChip(String value, bool enabled, ValueChanged<String> onPicked) => Pressable(
    label: value,
    onTap: enabled
        ? () async {
            final t = await pickTime(context, value);
            if (t != null) onPicked(fmtTime(t));
          }
        : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: wellDecoration(radius: 12),
      child: Text(
        value,
        style: ts(18, w: FontWeight.w800, c: enabled ? kPrimary : kFaint),
      ),
    ),
  );

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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 130),
            children: [
              FadeUp(
                child: ScreenTitle(caption: 'Thông báo & màn hình khóa', title: 'Nhắc nhở'),
              ),
              const SizedBox(height: 16),
              _status(),
              _card(
                delay: const Duration(milliseconds: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _head(
                      Ic.pin,
                      'yellow',
                      'Ghi chú trên màn hình khóa',
                      'Luôn hiện, không tự mất',
                      trailing: ClaySwitch(
                        value: s.pinnedOn,
                        label: 'Ghim ghi chú lên màn hình khóa',
                        onChanged: (v) {
                          widget.store.updateSettings((x) {
                            x.pinnedOn = v;
                            x.pinnedNote = _note.text;
                          });
                          if (v && _note.text.trim().isEmpty) _toast('Viết ghi chú bên dưới để hiện lên màn hình khóa');
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 200,
                      onChanged: _onNote,
                      style: ts(15, w: FontWeight.w600),
                      decoration: const InputDecoration(hintText: 'VD: Mang hồ sơ học bổng. Gọi mẹ lúc 20:00.', counterText: ''),
                    ),
                    const SizedBox(height: 12),
                    _lockPreview(s.pinnedOn ? (_note.text.trim().isEmpty ? 'Ghi chú của bạn sẽ hiện ở đây' : _note.text.trim()) : null),
                  ],
                ),
              ),
              _card(
                delay: const Duration(milliseconds: 120),
                child: Column(
                  children: [
                    _head(
                      Ic.sun,
                      'peach',
                      'Nhắc mỗi ngày',
                      'Tóm tắt lịch, khung giờ & việc trong ngày',
                      trailing: ClaySwitch(
                        value: s.dailyOn,
                        label: 'Nhắc mỗi ngày',
                        onChanged: (v) => widget.store.updateSettings((x) => x.dailyOn = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Giờ nhắc',
                            overflow: TextOverflow.ellipsis,
                            style: ts(14, w: FontWeight.w700, c: s.dailyOn ? kInk : kFaint),
                          ),
                        ),
                        _timeChip(s.dailyTime, s.dailyOn, (v) => widget.store.updateSettings((x) => x.dailyTime = v)),
                      ],
                    ),
                  ],
                ),
              ),
              _card(
                delay: const Duration(milliseconds: 180),
                child: Column(
                  children: [
                    _head(
                      Ic.timer,
                      'lavender',
                      'Nhắc việc chưa xong',
                      s.intervalOn ? 'Mỗi ${_hours(s.intervalHours)} · đang còn $open việc' : 'Lặp lại sau mỗi X giờ',
                      trailing: ClaySwitch(
                        value: s.intervalOn,
                        label: 'Nhắc việc chưa xong',
                        onChanged: (v) => widget.store.updateSettings((x) => x.intervalOn = v),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Mỗi',
                          style: ts(14, w: FontWeight.w700, c: s.intervalOn ? kInk : kFaint),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: kViolet,
                              inactiveTrackColor: kTrack,
                              thumbColor: Colors.white,
                              overlayColor: kViolet.withValues(alpha: 0.15),
                              trackHeight: 8,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 4, pressedElevation: 8),
                              valueIndicatorColor: kViolet,
                              valueIndicatorTextStyle: ts(13, w: FontWeight.w800, c: Colors.white),
                            ),
                            child: Slider(
                              value: s.intervalHours.clamp(0.5, 12),
                              min: 0.5,
                              max: 12,
                              divisions: 23,
                              label: _hours(s.intervalHours),
                              onChanged: s.intervalOn ? (v) => widget.store.updateSettings((x) => x.intervalHours = v) : null,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            _hours(s.intervalHours),
                            textAlign: TextAlign.right,
                            style: ts(15, w: FontWeight.w800, c: s.intervalOn ? kViolet : kFaint),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Trong khung',
                            overflow: TextOverflow.ellipsis,
                            style: ts(14, w: FontWeight.w700, c: s.intervalOn ? kInk : kFaint),
                          ),
                        ),
                        _timeChip(s.intervalFrom, s.intervalOn, (v) => widget.store.updateSettings((x) => x.intervalFrom = v)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('–', style: ts(16, c: kMuted)),
                        ),
                        _timeChip(s.intervalTo, s.intervalOn, (v) => widget.store.updateSettings((x) => x.intervalTo = v)),
                      ],
                    ),
                  ],
                ),
              ),
              _card(
                delay: const Duration(milliseconds: 220),
                child: _head(
                  Ic.sparkles,
                  'mint',
                  'Hiệu ứng chuyển động',
                  s.motion ? 'Thẻ nổi, nhịp, trôi… Tắt nếu máy chạy chậm' : 'Đang tắt để app chạy nhẹ hơn',
                  trailing: ClaySwitch(
                    value: s.motion,
                    label: 'Hiệu ứng chuyển động',
                    onChanged: (v) => widget.store.updateSettings((x) => x.motion = v),
                  ),
                ),
              ),
              _card(
                delay: const Duration(milliseconds: 240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _head(Ic.bellRing, 'pink', 'Thử thông báo', 'Xem thông báo trông thế nào'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClayButton(
                            label: 'Hiện ngay',
                            light: true,
                            expand: true,
                            height: 46,
                            onTap: () async {
                              await NotificationService.instance.showNow(
                                'Họp nhóm dự án',
                                '14:00 – 15:00 · Phòng 3\nNhớ mang laptop và bản nháp báo cáo.',
                              );
                              _refresh();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClayButton(
                            label: 'Sau 10 giây',
                            expand: true,
                            height: 46,
                            onTap: () async {
                              await NotificationService.instance.scheduleTest(10);
                              _toast('Đã hẹn! Khóa máy lại, 10 giây nữa sẽ có thông báo.');
                              _refresh();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FadeUp(
                delay: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFFFF6D6), borderRadius: BorderRadius.circular(18)),
                  child: Text(
                    'Để ghi chú hiện đầy đủ trên màn hình khóa: Cài đặt › Thông báo › Màn hình khóa › “Hiện tất cả nội dung”. '
                    'Máy Xiaomi, Oppo, Vivo, Samsung: bật “Tự khởi động” và đặt Pin “Không hạn chế” cho Mochi Planner để nhắc đúng giờ.',
                    style: ts(12.5, c: const Color(0xFF6E5A0C), h: 1.5),
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

  Widget _status() {
    final ok = _notif && _exact;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FadeUp(
        child: Clay(
          color: ok ? const Color(0xFFE3F7EC) : const Color(0xFFFFEAF1),
          tint: ok ? kGreen : kPrimary,
          radius: 24,
          depth: 0.6,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(ok ? Ic.circleCheck : Ic.bellOff, size: 20, color: ok ? const Color(0xFF23704C) : kDanger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(ok ? 'Nhắc nhở đang hoạt động' : 'Cần cấp quyền để nhắc đúng giờ', style: ts(15, w: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Thông báo: ${_notif ? 'đã bật' : 'chưa bật'} · Báo thức chính xác: ${_exact ? 'đã bật' : 'chưa bật'}',
                style: ts(12.5, c: kMuted),
              ),
              Text('Đang hẹn sẵn $_pending thông báo', style: ts(12.5, c: kMuted)),
              if (!ok) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClayButton(
                        label: 'Cấp quyền',
                        expand: true,
                        height: 44,
                        onTap: () async {
                          await NotificationService.instance.requestPermissions();
                          await widget.store.reschedule();
                          _refresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClayButton(
                        label: 'Mở cài đặt',
                        light: true,
                        expand: true,
                        height: 44,
                        onTap: () => NotificationService.instance.openSettings(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Khung xem trước nhỏ: ghi chú trên màn hình khóa.
  Widget _lockPreview(String? note) {
    final now = DateTime.now();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 168,
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(-0.6, -1), radius: 1.4, colors: [Color(0xFF5B3A86), Color(0xFF2E1F45)]),
        ),
        child: Stack(
          children: [
            Positioned(right: -30, top: -10, child: _orb(110, const [Color(0xFFFFE6F0), Color(0xFFF7A8C8), kPrimary])),
            Positioned(left: -24, bottom: -30, child: _orb(80, const [Color(0xFFF3EDFF), Color(0xFFC3AEF7), kViolet])),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${two(now.hour)}:${two(now.minute)}',
                    textAlign: TextAlign.center,
                    style: ts(34, w: FontWeight.w300, c: Colors.white, h: 1),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: note == null
                        ? Text(
                            'Ghi chú đang tắt',
                            key: const ValueKey('off'),
                            textAlign: TextAlign.center,
                            style: ts(13, c: Colors.white70),
                          )
                        : Container(
                            key: const ValueKey('on'),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Ic.pin, size: 12, color: Color(0xFFFFE58A)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'GHI CHÚ GHIM · MOCHI',
                                      style: ts(10, w: FontWeight.w800, c: Colors.white, ls: 0.6),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  note,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: ts(13.5, w: FontWeight.w700, c: Colors.white),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orb(double size, List<Color> c) => Loop(
    period: const Duration(seconds: 5),
    builder: (_, t, child) => Transform.translate(offset: Offset(6 * t, -8 * t), child: child),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-0.35, -0.4), colors: c, stops: const [0, 0.4, 1]),
      ),
    ),
  );
}
