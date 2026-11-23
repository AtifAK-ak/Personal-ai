/// Groq model policy (same rules as backend/app/services/providers.py).
/// Primary model first, one backup. No other model is ever chosen automatically.
const String kGroqPrimary =
    String.fromEnvironment('GROQ_MODEL', defaultValue: 'openai/gpt-oss-120b');
const String kGroqBackup =
    String.fromEnvironment('GROQ_BACKUP_MODEL', defaultValue: 'openai/gpt-oss-20b');
const List<String> kGroqModels = [kGroqPrimary, kGroqBackup];

enum ModelProblem { model, json }

class GroqPolicy {
  GroqPolicy._();

  static const List<String> _modelWords = [
    'model_not_found', 'model_decommissioned', 'decommission', 'deprecated',
    'no longer supported', 'does not exist', 'not found', 'unsupported model',
    'is not supported', 'not available',
  ];
  static const List<String> _jsonWords = [
    'response_format', 'json_object', 'json mode', 'json_validate', 'structured output',
  ];

  /// model: not found / retired / unsupported. json: JSON mode unsupported.
  /// null: not a model problem. Only HTTP 400 and 404 can be model problems, so
  /// 401/403/429/5xx never cause a model switch.
  static ModelProblem? classify(int status, String code, String message) {
    if (status != 400 && status != 404) return null;
    final text = '$code $message'.toLowerCase();
    if (_jsonWords.any(text.contains)) return ModelProblem.json;
    final c = code.toLowerCase();
    if (c == 'model_not_found' || c == 'model_decommissioned') return ModelProblem.model;
    if (text.contains('model') && _modelWords.any(text.contains)) return ModelProblem.model;
    return null;
  }
}
