import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'clay.dart';
import 'routine_editor.dart';

Future<void> openEventEditor(BuildContext context, AppStore store, {Event? event, DateTime? day, int? minute}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EventEditorScreen(store: store, event: event, day: day, minute: minute),
    ),
  );
}

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({super.key, required this.store, this.event, this.day, this.minute});
  final AppStore store;
  final Event? event;
  final DateTime? day;
  final int? minute;

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _date;
  late bool _allDay;
  late String _start;
  late String _end;
  late Repeat _repeat;
  late int? _remind;
  late String _color;
  bool _titleError = false;

  bool get _editing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.day ?? dateOnly(widget.day ?? DateTime.now());
    _allDay = e != null && e.start == null;
    if (e?.start != null) {
      _start = e!.start!;
      _end = e.end ?? minToHhmm(hhmmToMin(e.start!) + 60);
    } else {
      final m = widget.minute ?? 9 * 60;
      _start = minToHhmm(m);
      _end = minToHhmm(m + 60);
    }
    _repeat = e?.repeat ?? Repeat.none;
    _remind = e == null ? 10 : e.remind;
    _color = e?.color ?? 'pink';
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (d != null) setState(() => _date = d);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    final ev = widget.event?.copy() ?? Event(title: title, date: isoDate(_date));
    ev
      ..title = title
      ..date = isoDate(_date)
      ..start = _allDay ? null : _start
      ..end = _allDay ? null : _end
      ..repeat = _repeat
      ..remind = _remind
      ..color = _color
      ..note = _note.text.trim();
    widget.store.upsertEvent(ev);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Xóa lịch này?', style: ts(18, w: FontWeight.w800)),
        content: Text(_repeat == Repeat.none ? 'Lịch sẽ bị xóa vĩnh viễn.' : 'Toàn bộ chuỗi lịch lặp sẽ bị xóa.', style: ts(14, c: kMuted)),
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
      widget.store.deleteEvent(widget.event!.id);
      Navigator.of(context).pop();
    }
  }

  Widget _section({required Widget child, int i = 0}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: FadeUp(
      delay: Duration(milliseconds: 50 * i),
      child: Clay(radius: 24, depth: 0.6, padding: const EdgeInsets.all(14), child: child),
    ),
  );

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

  Widget _choices<T>(String label, IconData icon, List<(T, String)> options, T value, ValueChanged<T> onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 17, color: kPrimary),
          const SizedBox(width: 8),
          Text(label, style: ts(14, w: FontWeight.w800)),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in options)
            Pressable(
              label: o.$2,
              onTap: () => onChanged(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: o.$1 == value
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [lighten(kPrimary, .15), kPrimary],
                        ),
                        boxShadow: clayShadow(kPrimary, depth: 0.5),
                      )
                    : wellDecoration(radius: 12),
                child: Text(
                  o.$2,
                  style: ts(13, w: FontWeight.w700, c: o.$1 == value ? Colors.white : kMuted),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final dateText = '${weekdayLong[_date.weekday - 1]}, ${_date.day} tháng ${_date.month}, ${_date.year}';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  ClayIconButton(icon: Ic.x, label: 'Đóng', onTap: () => Navigator.pop(context)),
                  Expanded(
                    child: Text(
                      _editing ? 'Sửa lịch' : 'Lịch mới',
                      textAlign: TextAlign.center,
                      style: ts(19, w: FontWeight.w800),
                    ),
                  ),
                  if (_editing)
                    ClayIconButton(icon: Ic.trash2, label: 'Xóa lịch', fg: kDanger, onTap: _delete)
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                children: [
                  FadeUp(
                    child: TextField(
                      controller: _title,
                      autofocus: !_editing,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 80,
                      style: ts(18, w: FontWeight.w800),
                      onChanged: (_) => _titleError ? setState(() => _titleError = false) : null,
                      decoration: InputDecoration(
                        hintText: 'Tên lịch: họp nhóm, học tiếng Nhật…',
                        counterText: '',
                        errorText: _titleError ? 'Hãy nhập tên lịch nhé' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _section(
                    i: 1,
                    child: Column(
                      children: [
                        Pressable(
                          scale: 0.98,
                          onTap: _pickDate,
                          label: dateText,
                          child: Row(
                            children: [
                              const IconTile(icon: Ic.calendarDays, color: 'pink', size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(dateText, style: ts(15, w: FontWeight.w700)),
                              ),
                              const Icon(Ic.chevronRight, size: 18, color: kMuted),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const IconTile(icon: Ic.sun, color: 'yellow', size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Cả ngày', style: ts(15, w: FontWeight.w700)),
                            ),
                            ClaySwitch(value: _allDay, label: 'Cả ngày', onChanged: (v) => setState(() => _allDay = v)),
                          ],
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          child: _allDay
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    children: [
                                      _timeBox(
                                        'Bắt đầu',
                                        _start,
                                        (v) => setState(() {
                                          final dur = hhmmToMin(_end) - hhmmToMin(_start);
                                          _start = v;
                                          _end = minToHhmm(hhmmToMin(v) + (dur > 0 ? dur : 60));
                                        }),
                                      ),
                                      const SizedBox(width: 10),
                                      _timeBox('Kết thúc', _end, (v) => setState(() => _end = v)),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  _section(
                    i: 2,
                    child: _choices<int?>(
                      'Nhắc nhở',
                      Ic.bellRing,
                      [for (final e in remindOptions.entries) (e.key, e.value)],
                      _remind,
                      (v) => setState(() => _remind = v),
                    ),
                  ),
                  _section(
                    i: 3,
                    child: _choices<Repeat>(
                      'Lặp lại',
                      Ic.repeat,
                      [for (final r in Repeat.values) (r, r.label)],
                      _repeat,
                      (v) => setState(() => _repeat = v),
                    ),
                  ),
                  _section(
                    i: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Ic.palette, size: 17, color: kPrimary),
                            const SizedBox(width: 8),
                            Text('Màu', style: ts(14, w: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 10),
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
                      ],
                    ),
                  ),
                  FadeUp(
                    delay: const Duration(milliseconds: 250),
                    child: TextField(
                      controller: _note,
                      maxLines: 3,
                      maxLength: 300,
                      style: ts(15, w: FontWeight.w500),
                      decoration: const InputDecoration(hintText: 'Ghi chú nhỏ (hiện trong thông báo)…', counterText: ''),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: ClayButton(label: 'Lưu', icon: Ic.check, expand: true, onTap: _save),
            ),
          ],
        ),
      ),
    );
  }
}
