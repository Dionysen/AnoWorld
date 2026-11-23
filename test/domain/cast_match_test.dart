import 'package:anoworld/domain/models/cast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cast = <CastMember>[
    CastMember(id: 'c1', name: '梦涵', aliases: <String>['苏姐']),
    CastMember(id: 'c2', name: '姬皓月'),
  ];

  test('normalizes quotes, spacing and trailing notes', () {
    expect(normalizeCastName('「梦涵」'), '梦涵');
    expect(normalizeCastName('梦涵（冷笑）'), '梦涵');
    expect(normalizeCastName('梦 涵'), '梦涵');
    expect(normalizeCastName('『梦涵』'), '梦涵');
    expect(normalizeCastName('  '), '');
  });

  test('matches by id, normalized name and alias', () {
    expect(castMemberForSpeaker(cast, 'c1')?.id, 'c1');
    expect(castMemberForSpeaker(cast, '梦涵（低声）')?.id, 'c1');
    expect(castMemberForSpeaker(cast, '苏姐')?.id, 'c1');
    expect(castMemberForSpeaker(cast, '姬 皓月')?.id, 'c2');
    expect(castMemberForSpeaker(cast, '路人甲'), isNull);
  });

  test('aliases survive json round-trip', () {
    final json = const CastMember(
      id: 'c1',
      name: '梦涵',
      aliases: <String>['苏姐'],
    ).toJson();
    expect(CastMember.fromJson(json).aliases, <String>['苏姐']);
  });
}
