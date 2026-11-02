import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'clay.dart';

Future<void> openRoutineEditor(BuildContext context, AppStore store, {RoutineBlock? block, Set<int>? days}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    builder: (_) => RoutineEditor(store: store, block: block, days: days),
  );
}

Future<TimeOfDay?> pickTime(BuildContext context, String current) => showTimePicker(
  context: context,
  initialTime: TimeOfDay(hour: hhmmToMin(current) ~/ 60, minute: hhmmToMin(current) % 60),
  helpText: 'Chọn giờ',
  cancelText: 'Hủy',
  confirmText: 'Chọn',
  builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
);

String fmtTime(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

class RoutineEditor extends StatefulWidget {
  const RoutineEditor({super.key, required this.store, this.block, this.days});
  final AppStore store;
  final RoutineBlock? block;
  final Set<int>? days;

  @override
  State<RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<RoutineEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.block?.title ?? '');
  late String _start = widget.block?.start ?? '21:30';
  late String _end = widget.block?.end ?? '22:00';
  late Set<int> _days = {
    ...(widget.block?.days ?? widget.days ?? {1, 2, 3, 4, 5}),
  };
  late String _color = widget.block?.color ?? 'lavender';
  late bool _remind = widget.block?.remind ?? true;
  late bool _lock = widget.block?.lockScreen ?? false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final t = _title.text.trim();
    if (t.isEmpty) return setState(() => _error = 'Đặt tên cho khung giờ nhé');
    if (_days.isEmpty) return setState(() => _error = 'Chọn ít nhất một ngày');
    if (hhmmToMin(_end) <= hhmmToMin(_start)) return setState(() => _error = 'Giờ kết thúc phải sau giờ bắt đầu');
    final b = widget.block?.copy() ?? RoutineBlock(title: t, start: _start, end: _end, days: _days);
    b
      ..title = t
      ..start = _start
      ..end = _end
      ..days = _days
      ..color = _color
      ..remind = _remind
      ..lockScreen = _lock;
    widget.store.upsertRoutine(b);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Xóa khung giờ này?', style: ts(18, w: FontWeight.w800)),
        content: Text('“${widget.block!.title}” sẽ không lặp lại nữa.', style: ts(14, c: kMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              'Hủy',
              style: ts(14, w: FontWeight.w700, c: kMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              'Xóa',
              style: ts(14, w: FontWeight.w800, c: kDanger),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.store.deleteRoutine(widget.block!.id);
      Navigator.pop(context);
    }
  }

  Widget _timeBox(String label, String value, ValueChanged<String> onPicked) => Expanded(
    child: Pressable(
      scale: 0.97,
      label: '$label $value',
      onTap: () async {
        final t = await pickTime(context, value);
        if (t != null) onPicked(fmtTime(t));
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: wellDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: ts(12, w: FontWeight.w700, c: kMuted),
            ),
            Text(value, style: ts(24, w: FontWeight.w800)),
          ],
        ),
      ),
    ),
  );

  Widget _switchRow(IconData icon, String text, String? hint, bool v, ValueChanged<bool> onChanged) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 20, color: kViolet),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: ts(14, w: FontWeight.w700)),
              if (hint != null) Text(hint, style: ts(12, c: kMuted)),
            ],
          ),
        ),
        ClaySwitch(value: v, onChanged: onChanged, label: text),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: const Color(0xFFE4D3E2), borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(widget.block == null ? 'Khung giờ mới' : 'Sửa khung giờ', style: ts(20, w: FontWeight.w800)),
                ),
                if (widget.block != null) ClayIconButton(icon: Ic.trash2, label: 'Xóa khung giờ', fg: kDanger, size: 40, onTap: _delete),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              autofocus: widget.block == null,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              style: ts(16, w: FontWeight.w700),
              decoration: const InputDecoration(hintText: 'Tên: thiền, học bài, chạy bộ…', counterText: ''),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _timeBox(
                  'Bắt đầu',
                  _start,
                  (v) => setState(() {
                    final dur = hhmmToMin(_end) - hhmmToMin(_start);
                    _start = v;
                    _end = minToHhmm(hhmmToMin(v) + (dur > 0 ? dur : 30));
                  }),
                ),
                const SizedBox(width: 10),
                _timeBox('Kết thúc', _end, (v) => setState(() => _end = v)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Lặp vào các ngày',
              style: ts(13, w: FontWeight.w700, c: kMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var d = 1; d <= 7; d++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        selected: _days.contains(d),
                        child: Pressable(
                          label: weekdayLong[d - 1],
                          scale: 0.9,
                          onTap: () => setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 44,
                            alignment: Alignment.center,
                            transform: Matrix4.translationValues(0, _days.contains(d) ? -2 : 0, 0),
                            decoration: _days.contains(d)
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [lighten(kViolet, .2), kViolet],
                                    ),
                                    boxShadow: clayShadow(kViolet, depth: 0.6),
                                  )
                                : wellDecoration(radius: 14),
                            child: Text(
                              weekdayShort[d - 1],
                              style: ts(12, w: FontWeight.w800, c: _days.contains(d) ? Colors.white : kMuted),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              runSpacing: 8,
              children: [
                for (final q in const [
                  ('Mỗi ngày', {1, 2, 3, 4, 5, 6, 7}),
                  ('Ngày thường', {1, 2, 3, 4, 5}),
                  ('Cuối tuần', {6, 7}),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pressable(
                      onTap: () => setState(() => _days = {...q.$2}),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: kVioletSoft, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          q.$1,
                          style: ts(12, w: FontWeight.w700, c: const Color(0xFF5B3FA6)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Màu',
              style: ts(13, w: FontWeight.w700, c: kMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              runSpacing: 10,
              children: [
                for (final e in palette.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Pressable(
                      label: e.value.name,
                      scale: 0.88,
                      onTap: () => setState(() => _color = e.key),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        scale: _color == e.key ? 1.12 : 1,
                        child: Clay(
                          color: e.value.bg,
                          tint: e.value.fg,
                          radius: 14,
                          depth: _color == e.key ? 0.8 : 0.3,
                          width: 40,
                          height: 40,
                          child: _color == e.key ? Icon(Ic.check, size: 20, color: e.value.fg) : const SizedBox(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _switchRow(Ic.bellRing, 'Nhắc đúng giờ bắt đầu', null, _remind, (v) => setState(() => _remind = v)),
            _switchRow(Ic.lock, 'Hiện trên màn hình khóa', 'Ghim thông báo suốt khung giờ', _lock, (v) => setState(() => _lock = v)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: ts(13, w: FontWeight.w700, c: kDanger),
                ),
              ),
            const SizedBox(height: 14),
            ClayButton(label: 'Lưu khung giờ', icon: Ic.check, expand: true, onTap: _save),
          ],
        ),
      ),
    );
  }
}
