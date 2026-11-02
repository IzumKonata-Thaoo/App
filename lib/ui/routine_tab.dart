import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'clay.dart';
import 'routine_editor.dart';
import 'widgets.dart';

class RoutineTab extends StatefulWidget {
  const RoutineTab({super.key, required this.store});
  final AppStore store;

  @override
  State<RoutineTab> createState() => RoutineTabState();
}

class RoutineTabState extends State<RoutineTab> {
  int _day = DateTime.now().weekday; // 1..7

  void add() => openRoutineEditor(context, widget.store, days: {_day});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final all = widget.store.routines;
          final today = all.where((b) => b.days.contains(_day)).toList()..sort((a, b) => a.start.compareTo(b.start));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 130),
            children: [
              FadeUp(
                child: ScreenTitle(
                  caption: 'Khung giờ lặp lại mỗi tuần',
                  title: 'Lịch cố định',
                  trailing: ClayIconButton(icon: Ic.plus, label: 'Thêm khung giờ', color: kPrimary, fg: Colors.white, size: 48, onTap: add),
                ),
              ),
              const SizedBox(height: 18),
              FadeUp(delay: const Duration(milliseconds: 80), child: _weekMap(all)),
              const SizedBox(height: 22),
              SectionTitle(
                weekdayLong[_day - 1],
                trailing: Text(
                  '${today.length} khung giờ',
                  style: ts(12, w: FontWeight.w700, c: kMuted),
                ),
              ),
              if (today.isEmpty) const EmptyNote('Chưa có khung giờ nào cho ngày này.\nBấm + để thêm nhé', icon: Ic.calendarClock),
              for (var i = 0; i < today.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FadeUp(
                    key: ValueKey('$_day-${today[i].id}'),
                    delay: Duration(milliseconds: 50 * i),
                    child: _tile(today[i]),
                  ),
                ),
              const SizedBox(height: 6),
              _tip(),
            ],
          );
        },
      ),
    );
  }

  Widget _weekMap(List<RoutineBlock> all) {
    const trackH = 168.0;
    const px = trackH / (18 * 60); // 06:00 → 24:00
    return Clay(
      radius: 26,
      depth: 0.8,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            height: trackH + 22,
            child: Stack(
              children: [
                for (final h in const [6, 12, 18])
                  Positioned(
                    top: 22 + (h - 6) * 60 * px - 6,
                    right: 2,
                    child: Text('${h}h', style: ts(10, c: kMuted)),
                  ),
              ],
            ),
          ),
          for (var d = 1; d <= 7; d++)
            Expanded(
              child: Semantics(
                button: true,
                selected: d == _day,
                label: weekdayLong[d - 1],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _day = d),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 22,
                          child: Text(
                            weekdayShort[d - 1],
                            style: ts(11, w: FontWeight.w800, c: d == _day ? kPrimary : (d == 7 ? kDanger : kMuted)),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          height: trackH,
                          decoration: wellDecoration(
                            radius: 10,
                            color: d == _day ? kPrimarySoft : kWell,
                          ).copyWith(border: d == _day ? Border.all(color: kPrimary, width: 2) : null),
                          child: Stack(
                            children: [
                              for (final b in all.where((b) => b.days.contains(d)))
                                Positioned(
                                  left: 3,
                                  right: 3,
                                  top: ((b.span.$1 - 360).clamp(0, 18 * 60)) * px,
                                  height: ((b.span.$2 - b.span.$1) * px).clamp(5.0, trackH),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: Duration(milliseconds: 500 + 40 * d),
                                    curve: Curves.easeOutBack,
                                    builder: (_, v, c) => Transform.scale(scaleY: v, alignment: Alignment.topCenter, child: c),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(5),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [lighten(pastel(b.color).dot, .45), lighten(pastel(b.color).dot, .2)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(RoutineBlock b) {
    final p = pastel(b.color);
    return Pressable(
      scale: 0.97,
      label: b.title,
      onTap: () => openRoutineEditor(context, widget.store, block: b),
      child: Clay(
        radius: 20,
        depth: 0.6,
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 46,
              decoration: BoxDecoration(color: p.dot, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.start, style: ts(14, w: FontWeight.w800)),
                  Text(b.end, style: ts(12, c: kMuted)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(15, w: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          describeDays(b.days),
                          overflow: TextOverflow.ellipsis,
                          style: ts(12, c: kMuted),
                        ),
                      ),
                      if (b.lockScreen) ...[const SizedBox(width: 6), const Icon(Ic.lock, size: 12, color: kMuted)],
                    ],
                  ),
                ],
              ),
            ),
            ClaySwitch(value: b.remind, label: 'Nhắc khi bắt đầu', onChanged: (v) => widget.store.upsertRoutine(b.copy()..remind = v)),
          ],
        ),
      ),
    );
  }

  Widget _tip() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kVioletSoft, borderRadius: BorderRadius.circular(18)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Ic.sparkles, size: 18, color: Color(0xFF5B3FA6)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Công tắc bên phải là nhắc đúng giờ bắt đầu. Bật “Hiện trên màn hình khóa” trong từng khung giờ để giữ thông báo suốt thời gian đó.',
            style: ts(12.5, c: const Color(0xFF5B3FA6), h: 1.45),
          ),
        ),
      ],
    ),
  );
}
