import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/domain/ai/create/create_agent_runner.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_services.dart';
import 'package:anoworld/domain/card_import/card_sanitize_action.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTextClient implements AiTextClient {
  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  test('card.sanitize_draft via runner', () async {
    final runner = CreateAgentRunner();
    final draft = StCardImportDraft(
      title: 't',
      castItems: [
        StCardImportItem(
          id: 'c1',
          title: '甲',
          preview: 'x',
          value: const CastMember(
            id: 'c1',
            name: '甲',
            summary: '<b>hi</b>',
          ),
        ),
      ],
      worldBookItems: const [],
    );
    final ctx = CreateToolContext(
      draft: draft,
      services: CreateToolServices(textClient: _FakeTextClient()),
    );
    final result = await runner.runSingle(
      toolName: 'card.sanitize_draft',
      ctx: ctx,
    );
    expect(result.ok, isTrue);
    expect(result.payload?['changedFieldCount'], greaterThan(0));
    const action = CardSanitizeAction();
    final sanitized = action.run(draft);
    expect(sanitized.draft.castItems.first.value.summary, contains('**hi**'));
  });
}