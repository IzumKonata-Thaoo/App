import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

const _prio = {1: ('🌷', 'Thường'), 2: ('🌼', 'Quan trọng'), 3: ('🔥', 'Gấp')};

class TodoTab extends StatefulWidget {
  const TodoTab({super.key, required this.store});
  final AppStore store;

  @override
  State<TodoTab> createState() => _TodoTabState();
}

class _TodoTabState extends State<TodoTab> {
  final _text = TextEditingController();
  DateTime? _due;
  int _p = 1;
  String _filter = 'all';

  @override
  void dispose() {
    _text.dispose();
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const Text('Mochi Planner 🌸', style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w800)),
              const Text('Việc cần làm', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(todos.isEmpty ? 'Chưa có việc nào' : 'Đã xong $done/${todos.length}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      if (todos.isNotEmpty && done == todos.length) const Text('Tuyệt vời! 🎉'),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: todos.isEmpty ? 0 : done / todos.length,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFF9E8F1),
                        color: kAccent,
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    TextField(
                      controller: _text,
                      maxLength: 120,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _add(),
                      decoration: const InputDecoration(hintText: 'Thêm việc mới… ✨', counterText: ''),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: ActionChip(
                          avatar: Icon(Icons.event_rounded, size: 18, color: _due != null ? kAccent : kMuted),
                          label: Text(_due != null ? 'Hạn ${two(_due!.day)}/${two(_due!.month)}' : 'Không hạn', overflow: TextOverflow.ellipsis),
                          onPressed: _pickDue,
                        ),
                      ),
                      if (_due != null) IconButton(onPressed: () => setState(() => _due = null), icon: const Icon(Icons.close_rounded, size: 18)),
                      const SizedBox(width: 6),
                      PopupMenuButton<int>(
                        onSelected: (v) => setState(() => _p = v),
                        itemBuilder: (_) => [
                          for (final e in _prio.entries) PopupMenuItem(value: e.key, child: Text('${e.value.$1} ${e.value.$2}')),
                        ],
                        child: Chip(label: Text('${_prio[_p]!.$1} ${_prio[_p]!.$2}')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _add,
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                        child: const Text('Thêm'),
                      ),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final f in const [('all', 'Tất cả'), ('open', 'Chưa xong'), ('done', 'Đã xong')])
                  ChoiceChip(label: Text(f.$2), selected: _filter == f.$1, onSelected: (_) => setState(() => _filter = f.$1)),
              ]),
              const SizedBox(height: 8),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('Chưa có gì ở đây ✿', style: TextStyle(color: kMuted))),
                ),
              for (final t in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey(t.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: const Color(0xFFFFD6E2), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.delete_rounded, color: kDanger),
                    ),
                    onDismissed: (_) => widget.store.deleteTodo(t.id),
                    child: _row(t),
                  ),
                ),
              if (done > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: widget.store.clearDone, child: const Text('Xóa các việc đã xong')),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(Todo t) {
    Widget? badge;
    if (t.due != null) {
      final d = parseIso(t.due!);
      final delta = d.difference(dateOnly(DateTime.now())).inDays;
      final (bg, fg) = t.done
          ? (const Color(0xFFF3EEF6), kMuted)
          : delta < 0
              ? (const Color(0xFFFFD6E2), kDanger)
              : delta == 0
                  ? (const Color(0xFFFFF3B8), const Color(0xFF8A7410))
                  : (const Color(0xFFE3D4FA), const Color(0xFF6B4BA8));
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text('${two(d.day)}/${two(d.month)}', style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
      );
    }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.store.setTodoDone(t.id, !t.done),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          child: Row(children: [
            Checkbox(value: t.done, onChanged: (v) => widget.store.setTodoDone(t.id, v ?? false)),
            Text(_prio[t.prio]!.$1),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t.text,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: t.done ? kMuted : kInk,
                    decoration: t.done ? TextDecoration.lineThrough : null,
                  )),
            ),
            ?badge,
          ]),
        ),
      ),
    );
  }
}
