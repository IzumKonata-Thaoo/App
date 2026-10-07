import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

Future<void> openEventEditor(BuildContext context, AppStore store, {Event? event, DateTime? day, int? minute}) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => EventEditorScreen(store: store, event: event, day: day, minute: minute),
  ));
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
  late TimeOfDay _start;
  late TimeOfDay _end;
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
    TimeOfDay parse(String s) => TimeOfDay(hour: hhmmToMin(s) ~/ 60, minute: hhmmToMin(s) % 60);
    if (e?.start != null) {
      _start = parse(e!.start!);
      _end = parse(e.end ?? minToHhmm(hhmmToMin(e.start!) + 60));
    } else {
      final m = widget.minute ?? 9 * 60;
      _start = TimeOfDay(hour: m ~/ 60, minute: m % 60);
      final m2 = (m + 60).clamp(0, 23 * 60 + 59);
      _end = TimeOfDay(hour: m2 ~/ 60, minute: m2 % 60);
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

  String _fmt(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

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

  Future<TimeOfDay?> _pickTime(TimeOfDay init) => showTimePicker(
        context: context,
        initialTime: init,
        helpText: 'Chọn giờ',
        cancelText: 'Hủy',
        confirmText: 'Chọn',
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
      );

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
      ..start = _allDay ? null : _fmt(_start)
      ..end = _allDay ? null : _fmt(_end)
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
        title: const Text('Xóa lịch này?'),
        content: Text(_repeat == Repeat.none ? 'Lịch sẽ bị xóa vĩnh viễn.' : 'Toàn bộ chuỗi lịch lặp sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa', style: TextStyle(color: kDanger))),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.store.deleteEvent(widget.event!.id);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = '${weekdayLong[_date.weekday - 1]}, ${two(_date.day)}/${two(_date.month)}/${_date.year}';
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? '✿ Sửa lịch' : '✿ Thêm lịch mới', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [if (_editing) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded, color: kDanger), tooltip: 'Xóa')],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          TextField(
            controller: _title,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 80,
            onChanged: (_) => _titleError ? setState(() => _titleError = false) : null,
            decoration: InputDecoration(
              hintText: 'Tiêu đề: họp nhóm, học tiếng Nhật…',
              counterText: '',
              errorText: _titleError ? 'Hãy nhập tiêu đề nhé' : null,
              prefixIcon: const Icon(Icons.edit_rounded, color: kAccent),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.event_rounded, color: kAccent),
                title: Text(dateText, style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: _pickDate,
              ),
              const Divider(indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.wb_sunny_rounded, color: kAccent),
                title: const Text('Cả ngày', style: TextStyle(fontWeight: FontWeight.w700)),
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
              if (!_allDay) ...[
                const Divider(indent: 16, endIndent: 16),
                Row(children: [
                  Expanded(
                    child: ListTile(
                      leading: const Icon(Icons.schedule_rounded, color: kAccent),
                      title: Text(_fmt(_start), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      subtitle: const Text('Bắt đầu'),
                      onTap: () async {
                        final t = await _pickTime(_start);
                        if (t == null) return;
                        setState(() {
                          final dur = (_end.hour * 60 + _end.minute) - (_start.hour * 60 + _start.minute);
                          _start = t;
                          final e = (t.hour * 60 + t.minute + (dur > 0 ? dur : 60)).clamp(0, 23 * 60 + 59);
                          _end = TimeOfDay(hour: e ~/ 60, minute: e % 60);
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text(_fmt(_end), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      subtitle: const Text('Kết thúc'),
                      onTap: () async {
                        final t = await _pickTime(_end);
                        if (t != null) setState(() => _end = t);
                      },
                    ),
                  ),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(children: [
                DropdownButtonFormField<Repeat>(
                  initialValue: _repeat,
                  decoration: const InputDecoration(labelText: 'Lặp lại', prefixIcon: Icon(Icons.repeat_rounded, color: kAccent)),
                  items: [for (final r in Repeat.values) DropdownMenuItem(value: r, child: Text(r.label))],
                  onChanged: (v) => setState(() => _repeat = v ?? Repeat.none),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _remind,
                  decoration: InputDecoration(
                    labelText: 'Nhắc nhở',
                    prefixIcon: const Icon(Icons.notifications_active_rounded, color: kAccent),
                    helperText: _allDay && _remind != null ? 'Lịch cả ngày sẽ được tính từ 08:00' : null,
                  ),
                  items: [for (final e in remindOptions.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => setState(() => _remind = v),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Màu sắc', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(spacing: 12, runSpacing: 10, children: [
                  for (final e in palette.entries)
                    GestureDetector(
                      onTap: () => setState(() => _color = e.key),
                      child: Tooltip(
                        message: e.value.name,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: e.value.bg,
                            shape: BoxShape.circle,
                            border: Border.all(color: _color == e.key ? e.value.fg : e.value.bg, width: 3),
                          ),
                          child: _color == e.key ? Icon(Icons.check_rounded, color: e.value.fg) : null,
                        ),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(hintText: 'Ghi chú nhỏ…', prefixIcon: Icon(Icons.notes_rounded, color: kAccent)),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: const Text('Lưu')),
        ),
      ),
    );
  }
}
