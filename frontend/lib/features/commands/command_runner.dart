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

  static String _pct(int? p) => p == null ? '' : ' (now $p%)';

  static Future<CommandResult> run(ParsedCommand c) async {
    try {
      if (c.type == CommandType.flashlightOn) {
        final ok = await NativeBridge.flashlight(true);
        return ok
            ? const CommandResult('Flashlight is on.')
            : const CommandResult('Could not reach the device layer.', ok: false);
      } else if (c.type == CommandType.flashlightOff) {
        await NativeBridge.flashlight(false);
        return const CommandResult('Flashlight is off.');
      } else if (c.type == CommandType.volumeUp) {
        final p = await NativeBridge.volume('up');
        return CommandResult('Volume increased${_pct(p)}.');
      } else if (c.type == CommandType.volumeDown) {
        final p = await NativeBridge.volume('down');
        return CommandResult('Volume decreased${_pct(p)}.');
      } else if (c.type == CommandType.volumeMute) {
        await NativeBridge.volume('mute');
        return const CommandResult('Media volume muted.');
      } else if (c.type == CommandType.volumeUnmute) {
        final p = await NativeBridge.volume('unmute');
        return CommandResult('Media volume unmuted${_pct(p)}.');
      } else if (c.type == CommandType.openApp) {
        final label = await NativeBridge.openApp(c.arg ?? '');
        return CommandResult(label == null ? 'Could not reach the device layer.' : 'Opening $label.', ok: label != null);
      } else {
        final p = await NativeBridge.volume('set', percent: c.percent ?? 50);
        return CommandResult('Volume set${_pct(p)}.');
      }
    } on PlatformException catch (e) {
      return CommandResult('Could not do that: ${e.message ?? e.code}', ok: false);
    }
  }
}
