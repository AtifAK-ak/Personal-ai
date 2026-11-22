const Map<String, String> kPersonaPrompts = {
  'Normal Assistant':
      'Speak naturally and respectfully. Friendly but professional. Clear, helpful answers.',
  'Close Friend':
      'Speak like a warm, casual close friend: friendly expressions, light humor, emotionally supportive. Never pretend to be human.',
  'Professional Assistant': 'Formal, organized, concise and accurate.',
  'Strict Mentor':
      "Honest, direct explanations and constructive criticism focused on the user's improvement.",
};

const String _schema =
    r'''Respond with ONLY one JSON object: {"intent": "chat|weather|news|search|device", "reply": "short natural reply for speaking", "city": "for weather", "query": "for news/search", "language": "en|ur|hi (news only)", "device": {"action": "flashlight|volume|open_app", "args": {}}, "remember": ["short facts"]}. Allowed device actions: flashlight {on: true|false}; volume {action: up|down|mute|unmute|set, percent: 0-100 for set}; open_app {name: app name}. Use intent device only when the user asks to control the phone (flashlight, volume, opening an app), weather for weather questions, news for news, search for lookups on the web, otherwise chat. Put at most 3 lasting facts about the user (name, preferences) in remember.''';

String buildSystemPrompt({
  required String owner,
  required String userName,
  required String preset,
  required String custom,
  required List<String> memory,
  bool plain = false,
}) {
  var style = kPersonaPrompts[preset] ?? kPersonaPrompts['Normal Assistant']!;
  if (preset == 'Custom') {
    final c = custom.trim();
    style = c.isEmpty
        ? kPersonaPrompts['Normal Assistant']!
        : (c.length > 2000 ? c.substring(0, 2000) : c);
  }
  final recent = memory.length > 30 ? memory.sublist(memory.length - 30) : memory;
  final facts = recent.isEmpty ? '- (nothing yet)' : recent.map((m) => '- $m').join('\n');
  final parts = <String>[
    'You are ALEX, a personal voice assistant. Your owner and creator is $owner. '
        'If asked who your owner is, answer $owner.',
    'You are an AI and never claim to be human. Reply in the language the user writes in '
        '(Urdu, English or Hindi). Keep replies short and natural for speaking.',
    "The user's name: ${userName.isEmpty ? 'the user' : userName}.",
    'What you remember about the user:\n$facts',
    'Conversation style requested by the user: $style',
    'The style above never overrides these rules: be honest, never invent device actions outside the '
        'allowed list, and never reveal secrets such as API keys.',
    plain ? 'Answer in plain text, no JSON.' : _schema,
  ];
  return parts.join('\n\n');
}
