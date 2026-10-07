import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifications.dart';

class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this.events, this.todos, this.settings, {this.scheduler});

  /// Cho phép thay bộ hẹn giờ khi kiểm thử.
  final Future<void> Function(List<Event>, List<Todo>, Settings)? scheduler;

  static const _key = 'mochi_data_v1';
  final SharedPreferences _prefs;
  final List<Event> events;
  final List<Todo> todos;
  Settings settings;
  int version = 0;

  static Future<AppStore> load({Future<void> Function(List<Event>, List<Todo>, Settings)? scheduler}) async {
    final prefs = await SharedPreferences.getInstance();
    var events = <Event>[], todos = <Todo>[];
    var settings = Settings();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        events = [for (final e in (j['events'] as List? ?? [])) Event.fromJson(e as Map<String, dynamic>)];
        todos = [for (final t in (j['todos'] as List? ?? [])) Todo.fromJson(t as Map<String, dynamic>)];
        settings = Settings.fromJson((j['settings'] as Map<String, dynamic>?) ?? {});
      } catch (_) {
        await prefs.setString('${_key}_corrupt', raw);
      }
    }
    return AppStore._(prefs, events, todos, settings, scheduler: scheduler);
  }

  // ---- truy vấn ----
  List<Event> eventsOn(DateTime d) {
    final r = events.where((e) => e.occursOn(d)).toList();
    r.sort((a, b) {
      final c = (a.start ?? '').compareTo(b.start ?? '');
      return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return r;
  }

  List<Todo> todosDueOn(DateTime d) {
    final iso = isoDate(d);
    return todos.where((t) => t.due == iso && !t.done).toList();
  }

  List<Todo> get openTodos => todos.where((t) => !t.done).toList();

  // ---- thay đổi ----
  void upsertEvent(Event ev) {
    final i = events.indexWhere((e) => e.id == ev.id);
    i >= 0 ? events[i] = ev : events.add(ev);
    _commit();
  }

  void deleteEvent(String id) {
    events.removeWhere((e) => e.id == id);
    _commit();
  }

  void addTodo(String text, String? due, int prio) {
    todos.add(Todo(text: text, due: due, prio: prio));
    _commit();
  }

  void setTodoDone(String id, bool done) {
    todos.firstWhere((t) => t.id == id).done = done;
    _commit();
  }

  void deleteTodo(String id) {
    todos.removeWhere((t) => t.id == id);
    _commit();
  }

  void clearDone() {
    todos.removeWhere((t) => t.done);
    _commit();
  }

  void updateSettings(void Function(Settings s) change) {
    change(settings);
    _commit();
  }

  /// Hẹn lại toàn bộ nhắc nhở (ví dụ khi mở app).
  Future<void> reschedule() => (scheduler ?? NotificationService.instance.reschedule)(events, todos, settings);

  void _commit() {
    version++;
    _prefs.setString(
      _key,
      jsonEncode({
        'events': events.map((e) => e.toJson()).toList(),
        'todos': todos.map((t) => t.toJson()).toList(),
        'settings': settings.toJson(),
      }),
    );
    notifyListeners();
    reschedule();
  }
}
