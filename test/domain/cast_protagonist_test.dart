import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('castWithProtagonist keeps at most one protagonist', () {
    const a = CastMember(id: 'a', name: 'A', isProtagonist: true);
    const b = CastMember(id: 'b', name: 'B');
    const c = CastMember(id: 'c', name: 'C');

    final next = castWithProtagonist(
      [a, b, c],
      memberId: 'c',
      isProtagonist: true,
    );
    expect(protagonistOf(next)?.id, 'c');
    expect(next.singleWhere((m) => m.id == 'a').isProtagonist, isFalse);
  });

  test('rain night sample marks hero as protagonist', () {
    final project = const ProjectFactory().createRainNightSample();
    expect(project.protagonist?.name, '少年');
  });

  test('round-trip isProtagonist in json', () {
    const member = CastMember(id: 'x', name: 'Test', isProtagonist: true);
    final back = CastMember.fromJson(member.toJson());
    expect(back.isProtagonist, isTrue);
  });
}