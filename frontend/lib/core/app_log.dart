/// Small in-memory log (last 150 lines) shown in Settings, Diagnostics.
/// Never put API keys or tokens in here.
class AppLog {
  AppLog._();

  static final List<String> _lines = [];

  static String _two(int n) => n.toString().padLeft(2, '0');

  static void add(String message) {
    final t = DateTime.now();
    _lines.add('${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)} $message');
    if (_lines.length > 150) _lines.removeAt(0);
  }

  static List<String> get lines => List.unmodifiable(_lines);

  static void clear() => _lines.clear();
}
