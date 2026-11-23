import 'package:alex_ai/core/direct/groq_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default models are the two gpt-oss models', () {
    expect(kGroqModels, ['openai/gpt-oss-120b', 'openai/gpt-oss-20b']);
  });

  test('only model problems are classified as such', () {
    expect(GroqPolicy.classify(404, 'model_not_found', 'x'), ModelProblem.model);
    expect(
      GroqPolicy.classify(400, '', 'The model `a` does not exist or you do not have access'),
      ModelProblem.model,
    );
    expect(
      GroqPolicy.classify(400, '', 'response_format is not supported by this model'),
      ModelProblem.json,
    );
    expect(GroqPolicy.classify(400, 'invalid_request_error', 'messages is required'), isNull);
  });

  test('key and server errors never switch the model', () {
    for (final s in [401, 403, 429, 500, 503]) {
      expect(GroqPolicy.classify(s, 'model_not_found', 'model does not exist'), isNull);
    }
  });
}
