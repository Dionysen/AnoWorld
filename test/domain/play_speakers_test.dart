import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/runtime/play_speakers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cast = [
    CastMember(id: 'c1', name: '瑞希', summary: ''),
  ];

  test('老公 is player when not in cast', () {
    expect(
      speakerIsPlayer(
        speakerId: '老公',
        cast: cast,
        userAliases: const ['User'],
      ),
      isTrue,
    );
  });

  test('瑞希 is cast not player', () {
    expect(speakerIsCastMember('瑞希', cast), isTrue);
    expect(
      speakerIsPlayer(
        speakerId: 'c1',
        cast: cast,
        userAliases: const ['User'],
      ),
      isFalse,
    );
  });

  test('User alias is player', () {
    expect(
      speakerIsPlayer(
        speakerId: kPlayUserSpeakerId,
        cast: cast,
        userAliases: const ['User'],
      ),
      isTrue,
    );
  });
}
