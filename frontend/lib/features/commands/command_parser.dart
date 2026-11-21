enum CommandType {
  flashlightOn,
  flashlightOff,
  volumeUp,
  volumeDown,
  volumeMute,
  volumeUnmute,
  volumeSet,
  openApp,
}

class ParsedCommand {
  const ParsedCommand(this.type, [this.percent, this.arg]);
  final CommandType type;
  final int? percent;
  final String? arg;
}

/// Turns plain text into a device command. Pure Dart, no platform calls.
/// Only commands listed in CommandType can ever be produced.
class CommandParser {
  CommandParser._();

  static bool _en(String t, List<String> words) =>
      RegExp('\\b(${words.join('|')})\\b').hasMatch(t);

  static bool _ur(String t, List<String> words) => words.any(t.contains);

  static ParsedCommand? parse(String input) {
    final t = input.toLowerCase().trim();
    if (t.isEmpty) return null;

    final open = RegExp(r'^(?:alex[,\s]+)?(?:please\s+)?open\s+(?:the\s+)?(.+)$')
        .firstMatch(t);
    if (open != null) {
      final name = open.group(1)!.trim();
      if (name.isNotEmpty && name.length <= 40) {
        return ParsedCommand(CommandType.openApp, null, name);
      }
    }

    final torch =
        _en(t, ['flashlight', 'flash light', 'torch']) || _ur(t, ['ٹارچ', 'فلیش']);
    if (torch) {
      final off = _en(t, ['off']) || _ur(t, ['بند', 'آف']);
      return ParsedCommand(
          off ? CommandType.flashlightOff : CommandType.flashlightOn);
    }

    if (_en(t, ['unmute']) || _ur(t, ['ان میوٹ'])) {
      return const ParsedCommand(CommandType.volumeUnmute);
    }
    if (_en(t, ['mute']) || _ur(t, ['خاموش'])) {
      return const ParsedCommand(CommandType.volumeMute);
    }

    final volume = _en(t, ['volume', 'sound']) || _ur(t, ['آواز', 'والیوم']);
    if (volume) {
      final digits = RegExp(r'(\d{1,3})').firstMatch(t);
      if (digits != null) {
        final p = int.parse(digits.group(1)!).clamp(0, 100).toInt();
        return ParsedCommand(CommandType.volumeSet, p);
      }
      if (_en(t, ['increase', 'up', 'raise', 'louder', 'higher']) ||
          _ur(t, ['بڑھا', 'تیز', 'زیادہ'])) {
        return const ParsedCommand(CommandType.volumeUp);
      }
      if (_en(t, ['decrease', 'down', 'lower', 'reduce', 'quieter', 'softer']) ||
          _ur(t, ['کم', 'دھیم'])) {
        return const ParsedCommand(CommandType.volumeDown);
      }
    }
    return null;
  }

  /// Validates an action sent by the backend. Only whitelisted actions pass.
  static ParsedCommand? fromAction(Map<String, dynamic> a) {
    final action = a['action'];
    final raw = a['args'];
    final Map<dynamic, dynamic> args = raw is Map ? raw : const {};
    if (action == 'flashlight') {
      return ParsedCommand(args['on'] == true
          ? CommandType.flashlightOn
          : CommandType.flashlightOff);
    }
    if (action == 'volume') {
      switch (args['action']) {
        case 'up':
          return const ParsedCommand(CommandType.volumeUp);
        case 'down':
          return const ParsedCommand(CommandType.volumeDown);
        case 'mute':
          return const ParsedCommand(CommandType.volumeMute);
        case 'unmute':
          return const ParsedCommand(CommandType.volumeUnmute);
        case 'set':
          final p = args['percent'];
          if (p is num) {
            return ParsedCommand(CommandType.volumeSet, p.toInt().clamp(0, 100).toInt());
          }
          return null;
      }
      return null;
    }
    if (action == 'open_app') {
      final name = args['name'];
      if (name is String && name.trim().isNotEmpty && name.length <= 40) {
        return ParsedCommand(CommandType.openApp, null, name.trim());
      }
    }
    return null;
  }
}
