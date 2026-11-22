class VoiceInfo {
  const VoiceInfo(this.id, this.name, this.female, this.trait, this.language, this.emoji);
  final String id;
  final String name;
  final bool female;
  final String trait;
  final String language;
  final String emoji;
}

/// Ids match the backend (/voices). Fish Audio voice ids are configured on the backend.
const List<VoiceInfo> kVoices = [
  VoiceInfo('aisha', 'Aisha', true, 'Friendly', 'Hindi', '👩'),
  VoiceInfo('sara', 'Sara', true, 'Professional', 'Hindi', '🧕'),
  VoiceInfo('zara', 'Zara', true, 'Calm', 'Hindi', '👩‍🦱'),
  VoiceInfo('noor', 'Noor', true, 'Elegant', 'English', '👩🏽'),
  VoiceInfo('ali', 'Ali', false, 'Professional', 'Hindi', '👨‍💼'),
  VoiceInfo('ahmed', 'Ahmed', false, 'Cool', 'Hindi', '😎'),
  VoiceInfo('hassan', 'Hassan', false, 'Deep', 'English', '🧔'),
];
