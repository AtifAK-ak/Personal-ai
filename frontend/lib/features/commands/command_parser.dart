enum CommandType {
  flashlightOn,
  flashlightOff,
  volumeUp,
  volumeDown,
  volumeMute,
  volumeUnmute,
  volumeSet,
  openApp,
  openCamera,
  openPanel,
  battery,
  timeNow,
  mediaPlay,
  mediaPause,
  mediaNext,
  mediaPrev,
  mediaStop,
  recStart,
  recStop,
  recPause,
  recResume,
  contactSearch,
  callContact,
  navigate,
  mapsSearch,
  webSearch,
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
    final t = input
        .toLowerCase()
        .trim()
        .replaceFirst(RegExp(r'^alex[,\s]+'), '')
        .replaceFirst(RegExp(r'^please\s+'), '');
    if (t.isEmpty) return null;

    final rec = RegExp(r'\b(start|stop|pause|resume)\b.*\brecord(?:ing)?\b').firstMatch(t);
    if (rec != null) {
      switch (rec.group(1)) {
        case 'start':
          return const ParsedCommand(CommandType.recStart);
        case 'stop':
          return const ParsedCommand(CommandType.recStop);
        case 'pause':
          return const ParsedCommand(CommandType.recPause);
        default:
          return const ParsedCommand(CommandType.recResume);
      }
    }

    if (RegExp(r'\b(music|song|songs|track)\b').hasMatch(t) && !_en(t, ['volume'])) {
      if (_en(t, ['next'])) return const ParsedCommand(CommandType.mediaNext);
      if (_en(t, ['previous', 'last'])) return const ParsedCommand(CommandType.mediaPrev);
      if (_en(t, ['pause'])) return const ParsedCommand(CommandType.mediaPause);
      if (_en(t, ['stop'])) return const ParsedCommand(CommandType.mediaStop);
      if (_en(t, ['play', 'resume'])) return const ParsedCommand(CommandType.mediaPlay);
    }

    if (_en(t, ['battery', 'charging'])) return const ParsedCommand(CommandType.battery);

    if (_ur(t, ['what time', 'current time', 'the time', 'what date', 'current date', 'the date', "today's date"])) {
      return const ParsedCommand(CommandType.timeNow);
    }

    final panel = RegExp(r'\b(wifi|wi-fi|bluetooth|mobile network|mobile data|display|sound)\s+settings\b')
        .firstMatch(t);
    if (panel != null) {
      final p = panel.group(1)!;
      final name = p.startsWith('wi')
          ? 'wifi'
          : p.startsWith('mobile')
              ? 'mobile'
              : p;
      return ParsedCommand(CommandType.openPanel, null, name);
    }

    final contact = RegExp(r'^(?:find|search for|search|look up|show)\s+(.+?)\s+in my contacts$')
        .firstMatch(t);
    if (contact != null) {
      return ParsedCommand(CommandType.contactSearch, null, contact.group(1)!.trim());
    }
    final call = RegExp(r'^call\s+(.+)$').firstMatch(t);
    if (call != null && call.group(1)!.trim().length <= 40) {
      return ParsedCommand(CommandType.callContact, null, call.group(1)!.trim());
    }

    if (RegExp(r'^(?:open|launch)\s+(?:my\s+|the\s+)?camera$').hasMatch(t)) {
      return const ParsedCommand(CommandType.openCamera);
    }

    final nav = RegExp(r'^(?:navigate to|take me to|directions to|navigate)\s+(.+)$').firstMatch(t);
    if (nav != null) return ParsedCommand(CommandType.navigate, null, nav.group(1)!.trim());
    final near = RegExp(r'^(?:find|search for|show)\s+(?:me\s+)?(?:the\s+)?((?:nearest|nearby|closest)\s+.+)$')
        .firstMatch(t);
    if (near != null) return ParsedCommand(CommandType.mapsSearch, null, near.group(1)!.trim());
    final search = RegExp(r'^search\s+(?:for\s+)?(.+)$').firstMatch(t);
    if (search != null) {
      final q = search.group(1)!.trim();
      if (q.endsWith(' nearby')) {
        return ParsedCommand(CommandType.mapsSearch, null, q);
      }
      return ParsedCommand(CommandType.webSearch, null, q);
    }

    final open = RegExp(r'^(?:open|launch)\s+(?:the\s+)?(.+)$').firstMatch(t);
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
