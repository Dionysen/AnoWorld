import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/play_role.dart';
import 'package:anoworld/domain/runtime/play_speakers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = const ProjectFactory().createBlank(id: 'p', title: 't');
  final project = Project(
    meta: base.meta,
    worldBook: base.worldBook,
    cast: const <CastMember>[
      CastMember(id: 'c1', name: '瑞希', aliases: <String>['小瑞']),
      CastMember(id: 'c2', name: '旅人', aliases: <String>['老公']),
    ],
    main: base.main,
  );
  const role = PlayRole(playerCastId: 'c2', aliases: <String>['我']);

  test('cast name and alias resolve to the member id', () {
    expect(
      resolveDialogueSpeaker(speaker: '瑞希', project: project, role: role),
      (castId: 'c1', recognized: true),
    );
    expect(
      resolveDialogueSpeaker(speaker: '小瑞', project: project, role: role),
      (castId: 'c1', recognized: true),
    );
    expect(
      resolveDialogueSpeaker(
        speaker: '瑞希（冷笑）',
        project: project,
        role: role,
      ),
      (castId: 'c1', recognized: true),
    );
  });

  test('player aliases resolve to the player member', () {
    expect(
      resolveDialogueSpeaker(speaker: '老公', project: project, role: role),
      (castId: 'c2', recognized: true),
    );
    expect(
      resolveDialogueSpeaker(speaker: '我', project: project, role: role),
      (castId: 'c2', recognized: true),
    );
  });

  test('unknown names and narrator markers become narration', () {
    expect(
      resolveDialogueSpeaker(speaker: '黑衣人', project: project, role: role),
      (castId: null, recognized: false),
    );
    expect(
      resolveDialogueSpeaker(speaker: '旁白', project: project, role: role),
      (castId: null, recognized: false),
    );
    expect(
      resolveDialogueSpeaker(speaker: '', project: project, role: role),
      (castId: null, recognized: false),
    );
  });
}
