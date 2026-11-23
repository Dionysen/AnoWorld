import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/play_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = const ProjectFactory().createBlank(id: 'p', title: 't');
  final project = Project(
    meta: base.meta,
    worldBook: base.worldBook,
    cast: const <CastMember>[
      CastMember(id: 'c_card', name: '诸天', isProtagonist: true),
      CastMember(id: 'c_yue', name: '姬皓月'),
      CastMember(id: 'c_han', name: '梦涵', aliases: <String>['苏姐']),
    ],
    main: base.main,
  );

  test('focus stays the protagonist when the player is someone else', () {
    const role = PlayRole(playerCastId: 'c_yue');
    expect(role.playerIn(project)?.id, 'c_yue');
    expect(role.focusIn(project)?.id, 'c_card');
  });

  test('focus hands over to another member when the player is the lead', () {
    const role = PlayRole(playerCastId: 'c_card');
    expect(role.focusIn(project)?.id, 'c_yue');
  });

  test('player aliases include the member name and extra names', () {
    const role = PlayRole(playerCastId: 'c_han', aliases: <String>['我']);
    expect(role.speaksAsPlayer('苏姐', project), isTrue);
    expect(role.speaksAsPlayer('梦涵', project), isTrue);
    expect(role.speaksAsPlayer('我', project), isTrue);
    expect(role.speaksAsPlayer('姬皓月', project), isFalse);
    expect(role.labelIn(project, fallback: '玩家'), '梦涵');
  });

  test('missing role falls back to the fallback label', () {
    expect(
      const PlayRole().labelIn(project, fallback: '玩家'),
      '玩家',
    );
  });
}
