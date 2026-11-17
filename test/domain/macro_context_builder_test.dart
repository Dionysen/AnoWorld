import 'package:anoworld/domain/ai/macro_context_builder.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/foundation/ai/macro_service.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps persona and protagonist into macros', () {
    final persona = UserPersona(
      id: 'p',
      name: 'Lucy',
      description: '好奇的旅人',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    const hero = CastMember(
      id: 'h',
      name: '掌柜',
      summary: '客栈老板',
      personality: '精明',
      isProtagonist: true,
    );
    const side = CastMember(id: 's', name: '店小二');

    final context = const MacroContextBuilder().build(
      persona: persona,
      protagonist: hero,
      cast: [hero, side],
    );
    final text = MacroService(context).process(
      '你好 {{user}}，我是 {{char}}：{{description}}',
    );
    expect(text, contains('Lucy'));
    expect(text, contains('掌柜'));
    expect(text, contains('客栈老板'));
  });
}