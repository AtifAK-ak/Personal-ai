import 'package:flutter/services.dart';

import '../../core/native_bridge.dart';
import 'command_parser.dart';

class CommandResult {
  const CommandResult(this.message, {this.ok = true});
  final String message;
  final bool ok;
}

/// Executes a parsed command through the Kotlin layer and reports the result.
class CommandRunner {
  CommandRunner._();

  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  static String _pct(int? p) => p == null ? '' : ' (now $p%)';

  static CommandResult _done(bool ok, String good) => ok
      ? CommandResult(good)
      : const CommandResult('Could not reach the device layer.', ok: false);

  static Future<CommandResult> run(ParsedCommand c) async {
    try {
      final arg = c.arg ?? '';
      switch (c.type) {
        case CommandType.flashlightOn:
          return _done(await NativeBridge.flashlight(true), 'Flashlight is on.');
        case CommandType.flashlightOff:
          await NativeBridge.flashlight(false);
          return const CommandResult('Flashlight is off.');
        case CommandType.volumeUp:
          return CommandResult('Volume increased${_pct(await NativeBridge.volume('up'))}.');
        case CommandType.volumeDown:
          return CommandResult('Volume decreased${_pct(await NativeBridge.volume('down'))}.');
        case CommandType.volumeMute:
          await NativeBridge.volume('mute');
          return const CommandResult('Media volume muted.');
        case CommandType.volumeUnmute:
          return CommandResult('Media volume unmuted${_pct(await NativeBridge.volume('unmute'))}.');
        case CommandType.volumeSet:
          final p = await NativeBridge.volume('set', percent: c.percent ?? 50);
          return CommandResult('Volume set${_pct(p)}.');
        case CommandType.openApp:
          final label = await NativeBridge.openApp(arg);
          return label == null
              ? const CommandResult('Could not reach the device layer.', ok: false)
              : CommandResult('Opening $label.');
        case CommandType.openCamera:
          return _done(await NativeBridge.openCamera(), 'Opening the camera.');
        case CommandType.openPanel:
          return _done(await NativeBridge.openPanel(arg), 'Opening $arg settings.');
        case CommandType.battery:
          final b = await NativeBridge.battery();
          if (b == null) {
            return const CommandResult('Could not read the battery.', ok: false);
          }
          final charging = b['charging'] == true ? ', charging' : ', not charging';
          return CommandResult('Battery is at ${b['percent']}%$charging.');
        case CommandType.timeNow:
          final n = DateTime.now();
          final hh = n.hour % 12 == 0 ? 12 : n.hour % 12;
          final mm = n.minute.toString().padLeft(2, '0');
          final ap = n.hour >= 12 ? 'PM' : 'AM';
          return CommandResult(
              "It's $hh:$mm $ap, ${_days[n.weekday - 1]} ${n.day} ${_months[n.month - 1]} ${n.year}.");
        case CommandType.mediaPlay:
          return _done(await NativeBridge.mediaKey('play'), 'Playing.');
        case CommandType.mediaPause:
          return _done(await NativeBridge.mediaKey('pause'), 'Paused.');
        case CommandType.mediaNext:
          return _done(await NativeBridge.mediaKey('next'), 'Next track.');
        case CommandType.mediaPrev:
          return _done(await NativeBridge.mediaKey('previous'), 'Previous track.');
        case CommandType.mediaStop:
          return _done(await NativeBridge.mediaKey('stop'), 'Stopped.');
        case CommandType.recStart:
          final startPath = await NativeBridge.record('start');
          return startPath == null
              ? const CommandResult('Could not start recording.', ok: false)
              : const CommandResult('Recording started. Say "stop recording" to save it.');
        case CommandType.recStop:
          final stopPath = await NativeBridge.record('stop');
          return CommandResult(stopPath == null ? 'Recording stopped.' : 'Recording saved: $stopPath');
        case CommandType.recPause:
          await NativeBridge.record('pause');
          return const CommandResult('Recording paused.');
        case CommandType.recResume:
          await NativeBridge.record('resume');
          return const CommandResult('Recording resumed.');
        case CommandType.contactSearch:
          final hits = await NativeBridge.searchContacts(arg);
          if (hits.isEmpty) return CommandResult('No contact found for "$arg".');
          return CommandResult(hits.map((e) => '${e['name']}: ${e['number']}').join('\n'));
        case CommandType.callContact:
          final matches = await NativeBridge.searchContacts(arg);
          if (matches.isEmpty) return CommandResult('No contact found for "$arg".');
          if (matches.length > 1) {
            final names = matches.map((e) => e['name']).toSet().join(', ');
            return CommandResult('I found several matches: $names. Please say the full name.');
          }
          await NativeBridge.dial(matches.first['number'] ?? '');
          return CommandResult('Opening the dialer for ${matches.first['name']}. Press call to confirm.');
        case CommandType.navigate:
          return _done(await NativeBridge.openMaps(arg, navigate: true), 'Starting navigation to $arg.');
        case CommandType.mapsSearch:
          return _done(await NativeBridge.openMaps(arg), 'Searching maps for $arg.');
        default:
          return _done(await NativeBridge.webSearch(arg), 'Searching the web for $arg.');
      }
    } on PlatformException catch (e) {
      return CommandResult('Could not do that: ${e.message ?? e.code}', ok: false);
    }
  }
}
