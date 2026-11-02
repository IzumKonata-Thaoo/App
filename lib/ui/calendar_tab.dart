import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../reminder_planner.dart';
import '../store.dart';
import '../theme.dart';
import 'clay.dart';
import 'event_editor.dart';
import 'month_view.dart';
import 'routine_editor.dart';
import 'week_view.dart';
import 'widgets.dart';
import 'year_view.dart';

enum ViewMode { month, week, year }

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.store});
  final AppStore store;

  @override
  State<CalendarTab> createState() => CalendarTabState();
}

class CalendarTabState extends State<CalendarTab> {
  ViewMode mode = ViewMode.month;
  DateTime current = dateOnly(DateTime.now());
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void addEvent({int? minute}) => openEventEditor(context, widget.store, day: current, minute: minute);
  void editEvent(Event e) => openEventEditor(context, widget.store, event: e);
  void editRoutine(RoutineBlock b) => openRoutineEditor(context, widget.store, block: b);

  void _shift(int step) => setState(() {
    current = switch (mode) {
      ViewMode.month => addMonths(current, step),
      ViewMode.week => current.add(Duration(days: 7 * step)),
      ViewMode.year => addMonths(current, 12 * step),
    };
  });

  String get _period {
    switch (mode) {
      case ViewMode.month:
        return 'Tháng ${current.month}, ${current.year}';
      case ViewMode.year:
        return 'Năm ${current.year}';
      case ViewMode.week:
        final a = weekStart(current), b = a.add(const Duration(days: 6));
        return a.month == b.month ? '${a.day} – ${b.day} tháng ${b.month}' : '${a.day}/${a.month} – ${b.day}/${b.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: FadeUp(
                child: ScreenTitle(caption: fullDate(now), title: greetingFor(now.hour)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: SegmentedPill<ViewMode>(
                values: ViewMode.values,
                labels: const ['Tháng', 'Tuần', 'Năm'],
                selected: mode,
                onChanged: (m) => setState(() => mode = m),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(a),
                          child: c,
                        ),
                      ),
                      child: Text(
                        _period,
                        key: ValueKey(_period),
                        style: ts(18, w: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (current != dateOnly(now))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pressable(
                        onTap: () => setState(() => current = dateOnly(now)),
                        label: 'Về hôm nay',
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: kPrimarySoft, borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            'Hôm nay',
                            style: ts(12, w: FontWeight.w800, c: kPrimary),
                          ),
                        ),
                      ),
                    ),
                  ClayIconButton(icon: Ic.chevronLeft, label: 'Trước', size: 38, onTap: () => _shift(-1)),
                  const SizedBox(width: 8),
                  ClayIconButton(icon: Ic.chevronRight, label: 'Sau', size: 38, onTap: () => _shift(1)),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v < -350) _shift(1);
                  if (v > 350) _shift(-1);
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: c),
                  ),
                  child: _body(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final s = widget.store;
    switch (mode) {
      case ViewMode.month:
        return ListView(
          key: const ValueKey('month'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
          children: [
            NowCard(store: s),
            const SizedBox(height: 26),
            FadeUp(
              delay: const Duration(milliseconds: 80),
              child: Clay(
                radius: 26,
                depth: 0.7,
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                child: MonthGrid(store: s, current: current, onSelect: (d) => setState(() => current = d)),
              ),
            ),
            const SizedBox(height: 22),
            DayAgenda(store: s, day: current, onEditEvent: editEvent, onEditRoutine: editRoutine),
          ],
        );
      case ViewMode.week:
        return Padding(
          key: const ValueKey('week'),
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: Column(
            children: [
              WeekStrip(store: s, current: current, onSelect: (d) => setState(() => current = d)),
              const SizedBox(height: 12),
              Expanded(
                child: DayTimeline(
                  key: ValueKey(isoDate(current)),
                  store: s,
                  day: current,
                  onEditEvent: editEvent,
                  onEditRoutine: editRoutine,
                  onAddAt: (m) => addEvent(minute: m),
                ),
              ),
            ],
          ),
        );
      case ViewMode.year:
        return YearGrid(
          key: const ValueKey('year'),
          store: s,
          current: current,
          onOpenDay: (d) => setState(() {
            current = d;
            mode = ViewMode.month;
          }),
        );
    }
  }
}

/// Thẻ 3D trên cùng: việc đang diễn ra (kèm vòng tiến độ) hoặc việc sắp tới.
class NowCard extends StatelessWidget {
  const NowCard({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final items = itemsOn(store, dateOnly(now)).where((i) => i.span != null).toList();
    final live = items.where((i) => i.span!.$1 <= nowMin && nowMin < i.span!.$2).toList();
    final next = items.where((i) => i.span!.$1 > nowMin).toList();
    final open = store.openTodos.length;

    String badge, title, sub;
    double? progress;
    if (live.isNotEmpty) {
      final it = live.first;
      final (s, e) = it.span!;
      badge = 'Đang diễn ra · ${it.kind == ItemKind.routine ? 'Lịch cố định' : 'Lịch'}';
      title = it.title;
      sub = 'Đến ${it.end ?? minToHhmm(e)} · còn ${_dur(e - nowMin)}';
      progress = (nowMin - s) / (e - s);
    } else if (next.isNotEmpty) {
      final it = next.first;
      badge = 'Sắp tới · ${it.kind == ItemKind.routine ? 'Lịch cố định' : 'Lịch'}';
      title = it.title;
      sub = 'Lúc ${it.start} · còn ${_dur(it.span!.$1 - nowMin)} nữa';
    } else {
      badge = 'Hôm nay';
      title = items.isEmpty ? 'Ngày thảnh thơi' : 'Xong lịch hôm nay rồi';
      sub = open == 0 ? 'Không còn việc nào chưa xong' : 'Còn $open việc chưa xong';
    }

    return FadeUp(
      child: SizedBox(
        height: 142,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 26, right: 26, bottom: -16, height: 60, child: _layer(const Color(0xFFFFE0C7), const Color(0xFF965028))),
            Positioned(left: 12, right: 12, bottom: -8, height: 70, child: _layer(kVioletSoft, kViolet)),
            Positioned.fill(
              child: Float3D(
                child: Clay(
                  color: kPrimary,
                  tint: kPrimary,
                  radius: 28,
                  depth: 1.2,
                  padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                if (progress != null) ...[const PulseDot(), const SizedBox(width: 8)],
                                Flexible(
                                  child: Text(
                                    badge,
                                    overflow: TextOverflow.ellipsis,
                                    style: ts(12, w: FontWeight.w700, c: Colors.white.withValues(alpha: 0.92)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts(21, w: FontWeight.w800, c: Colors.white, h: 1.2),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Ic.clock, size: 15, color: Colors.white.withValues(alpha: 0.92)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    sub,
                                    overflow: TextOverflow.ellipsis,
                                    style: ts(13, c: Colors.white.withValues(alpha: 0.92)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (progress != null)
                        ProgressRing(
                          value: progress,
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: ts(15, w: FontWeight.w800, c: Colors.white),
                          ),
                        )
                      else
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                          child: Icon(next.isNotEmpty ? Ic.alarmClock : Ic.sparkles, color: Colors.white, size: 28),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _layer(Color c, Color tint) => Transform(
    alignment: Alignment.bottomCenter,
    transform: Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(0.14),
    child: Clay(color: c, tint: tint, radius: 26, depth: 0.6, child: const SizedBox.expand()),
  );

  static String _dur(int m) {
    if (m < 60) return '$m phút';
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? '$h giờ' : '$h giờ $r phút';
  }
}
