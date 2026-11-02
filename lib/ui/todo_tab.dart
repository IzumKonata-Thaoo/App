import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'clay.dart';
import 'widgets.dart';

const _prio = {
  3: ('Gấp', Color(0xFFFFD3E4), Color(0xFF8E2457)),
  2: ('Quan trọng', Color(0xFFFFF1B8), Color(0xFF6E5A0C)),
  1: ('Thường', Color(0xFFDDF6E8), Color(0xFF23704C)),
};

class TodoTab extends StatefulWidget {
  const TodoTab({super.key, required this.store});
  final AppStore store;

  @override
  State<TodoTab> createState() => TodoTabState();
}

class TodoTabState extends State<TodoTab> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  DateTime? _due;
  int _p = 1;
  String _filter = 'open';

  void focusInput() => _focus.requestFocus();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    widget.store.addTodo(t, _due != null ? isoDate(_due!) : null, _p);
    _text.clear();
    setState(() {
      _due = null;
      _p = 1;
    });
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Hạn chót',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (d != null) setState(() => _due = dateOnly(d));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final todos = widget.store.todos;
          final done = todos.where((t) => t.done).length;
          final shown = todos.where((t) => _filter == 'all' || (_filter == 'done') == t.done).toList()
            ..sort((a, b) {
              if (a.done != b.done) return a.done ? 1 : -1;
              if (a.prio != b.prio) return b.prio.compareTo(a.prio);
              return (a.due ?? '9999').compareTo(b.due ?? '9999');
            });
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 130),
            children: [
              FadeUp(
                child: ScreenTitle(caption: fullDate(DateTime.now()), title: 'Việc cần làm'),
              ),
              const SizedBox(height: 16),
              FadeUp(delay: const Duration(milliseconds: 60), child: _progress(done, todos.length)),
              const SizedBox(height: 16),
              FadeUp(delay: const Duration(milliseconds: 120), child: _composer()),
              const SizedBox(height: 14),
              SegmentedPill<String>(
                values: const ['open', 'all', 'done'],
                labels: const ['Chưa xong', 'Tất cả', 'Đã xong'],
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 14),
              if (shown.isEmpty)
                EmptyNote(_filter == 'done' ? 'Chưa hoàn thành việc nào' : 'Không còn việc nào — tuyệt vời!', icon: Ic.partyPopper),
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FadeUp(
                    key: ValueKey('${shown[i].id}-$_filter'),
                    delay: Duration(milliseconds: 40 * i),
                    child: Dismissible(
                      key: ValueKey(shown[i].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 22),
                        decoration: BoxDecoration(color: const Color(0xFFFFD6E2), borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Ic.trash2, color: kDanger),
                      ),
                      onDismissed: (_) => widget.store.deleteTodo(shown[i].id),
                      child: _row(shown[i]),
                    ),
                  ),
                ),
              if (done > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: widget.store.clearDone,
                    child: Text(
                      'Xóa các việc đã xong',
                      style: ts(13, w: FontWeight.w700, c: kPrimary),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _progress(int done, int total) {
    final left = total - done;
    return Clay(
      radius: 28,
      depth: 0.9,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Loop(
            period: const Duration(milliseconds: 3000),
            builder: (_, t, c) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(-0.18 + 0.12 * t)
                ..rotateX(0.10 + 0.06 * t)
                ..translateByDouble(0.0, -3 * t, 0.0, 1.0),
              child: c,
            ),
            child: Clay(
              color: kVioletSoft,
              tint: kViolet,
              radius: 28,
              width: 88,
              height: 88,
              child: Center(
                child: Clay(
                  color: kViolet,
                  tint: kViolet,
                  radius: 18,
                  width: 56,
                  height: 56,
                  child: Center(
                    child: Text(
                      '$done/$total',
                      style: ts(18, w: FontWeight.w800, c: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == 0 ? 'Chưa có việc nào' : (left == 0 ? 'Xong hết rồi, giỏi quá!' : 'Còn $left việc chưa xong'),
                  style: ts(16, w: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.store.settings.intervalOn
                      ? 'Nhắc lại sau mỗi ${_h(widget.store.settings.intervalHours)}'
                      : 'Bật nhắc định kỳ trong tab Nhắc nhở',
                  style: ts(12.5, c: kMuted),
                ),
                const SizedBox(height: 10),
                ShineBar(value: total == 0 ? 0 : done / total),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _h(double h) => h % 1 == 0 ? '${h.round()} giờ' : '${h.toStringAsFixed(1)} giờ';

  Widget _composer() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: _focus,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _add(),
              style: ts(15, w: FontWeight.w600),
              decoration: const InputDecoration(hintText: 'Thêm việc mới…', counterText: ''),
            ),
          ),
          const SizedBox(width: 10),
          ClayIconButton(icon: Ic.plus, label: 'Thêm việc', color: kPrimary, fg: Colors.white, size: 52, onTap: _add),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 8,
        children: [
          Pressable(
            onTap: _pickDue,
            label: 'Chọn hạn chót',
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _due != null ? kPrimarySoft : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Ic.calendarDays, size: 16, color: _due != null ? kPrimary : kMuted),
                  const SizedBox(width: 6),
                  Text(
                    _due != null ? 'Hạn ${two(_due!.day)}/${two(_due!.month)}' : 'Không hạn',
                    style: ts(12.5, w: FontWeight.w700, c: _due != null ? kPrimary : kMuted),
                  ),
                  if (_due != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _due = null),
                      child: const Icon(Ic.x, size: 15, color: kPrimary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          for (final e in _prio.entries)
            Pressable(
              onTap: () => setState(() => _p = e.key),
              label: e.value.$1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _p == e.key ? e.value.$2 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _p == e.key ? e.value.$3.withValues(alpha: 0.4) : kLine),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    e.value.$1,
                    style: ts(12, w: FontWeight.w800, c: _p == e.key ? e.value.$3 : kMuted),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _row(Todo t) {
    final pr = _prio[t.prio] ?? _prio[1]!;
    String? due;
    var dueColor = kMuted;
    if (t.due != null) {
      final d = parseIso(t.due!);
      final delta = d.difference(dateOnly(DateTime.now())).inDays;
      due = delta == 0
          ? 'Hôm nay'
          : delta == 1
          ? 'Ngày mai'
          : delta < 0
          ? 'Quá hạn · ${d.day}/${d.month}'
          : '${weekdayLong[d.weekday - 1]}, ${d.day}/${d.month}';
      if (!t.done && delta < 0) dueColor = kDanger;
      if (!t.done && delta == 0) dueColor = const Color(0xFF7A6410);
    }
    return Clay(
      radius: 20,
      depth: 0.6,
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      child: Row(
        children: [
          ClayCheck(value: t.done, label: t.text, onChanged: (v) => widget.store.setTodoDone(t.id, v)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 240),
                  style: ts(
                    15,
                    w: FontWeight.w700,
                    c: t.done ? kMuted : kInk,
                    deco: t.done ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                  child: Text(t.text),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: pr.$2, borderRadius: BorderRadius.circular(7)),
                      child: Text(
                        pr.$1,
                        style: ts(11, w: FontWeight.w800, c: pr.$3),
                      ),
                    ),
                    if (due != null) ...[const SizedBox(width: 8), Text(due, style: ts(12, c: dueColor))],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
