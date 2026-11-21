import 'package:alex_ai/features/commands/command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CommandType? type(String s) => CommandParser.parse(s)?.type;

  test('flashlight commands', () {
    expect(type('ALEX, turn on the flashlight'), CommandType.flashlightOn);
    expect(type('switch off my torch'), CommandType.flashlightOff);
  });

  test('volume commands', () {
    expect(type('increase the volume'), CommandType.volumeUp);
    expect(type('decrease the volume'), CommandType.volumeDown);
    expect(type('mute my phone'), CommandType.volumeMute);
    expect(type('unmute my phone'), CommandType.volumeUnmute);
    final set = CommandParser.parse('set volume to 50%');
    expect(set?.type, CommandType.volumeSet);
    expect(set?.percent, 50);
  });

  _extras();

  test('unknown text is not a command', () {
    expect(CommandParser.parse('hello there'), isNull);
    expect(CommandParser.parse(''), isNull);
  });
}

void _extras() {
  group('open app and backend actions', () {
    test('open app', () {
      final c = CommandParser.parse('ALEX, open YouTube');
      expect(c?.type, CommandType.openApp);
      expect(c?.arg, 'youtube');
    });

    test('backend actions are validated', () {
      expect(
        CommandParser.fromAction({'action': 'flashlight', 'args': {'on': true}})?.type,
        CommandType.flashlightOn,
      );
      expect(CommandParser.fromAction({'action': 'rm -rf', 'args': {}}), isNull);
      expect(
        CommandParser.fromAction({'action': 'volume', 'args': {'action': 'set', 'percent': 400}})?.percent,
        100,
      );
    });
  });
}
