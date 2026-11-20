import 'package:anoworld/domain/main/entity_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses each layer prefix', () {
    expect(EntityRef.parse('wb:wb_03').kind, EntityKind.worldBook);
    expect(EntityRef.parse('cast:c_02').kind, EntityKind.cast);
    expect(EntityRef.parse('node:n_5').kind, EntityKind.node);
    expect(EntityRef.parse('edge:e_p_1').kind, EntityKind.edge);
    expect(EntityRef.parse('preset:default').kind, EntityKind.preset);
    expect(EntityRef.parse('pe:pe_rain').kind, EntityKind.plotElement);
  });

  test('splits id from field', () {
    final ref = EntityRef.parse('wb:wb_03.body');
    expect(ref.id, 'wb_03');
    expect(ref.field, 'body');
    expect(ref.hasField, isTrue);
    expect(ref.format(), 'wb:wb_03.body');
  });

  test('whole-entity ref has no field and round-trips', () {
    final ref = EntityRef.parse('cast:c_02');
    expect(ref.hasField, isFalse);
    expect(ref.format(), 'cast:c_02');
  });

  test('trims surrounding whitespace', () {
    expect(EntityRef.parse('  node:n_1  ').format(), 'node:n_1');
  });

  test('rejects malformed refs', () {
    for (final raw in const [
      '',
      'wb_03',
      'wb:',
      ':wb_03',
      'nope:wb_03',
      'wb:wb_03.',
    ]) {
      expect(
        () => EntityRef.parse(raw),
        throwsA(isA<EntityRefException>()),
        reason: 'should reject "$raw"',
      );
    }
  });

  test('rejects unknown fields per layer', () {
    expect(
      () => EntityRef.parse('wb:wb_03.detail'),
      throwsA(isA<EntityRefException>()),
    );
    expect(
      () => EntityRef.parse('edge:e_p_1.body'),
      throwsA(isA<EntityRefException>()),
    );
    // Both fields exist, on their own layer.
    expect(EntityRef.parse('edge:e_p_1.detail').field, 'detail');
    expect(EntityRef.parse('wb:wb_03.body').field, 'body');
  });

  test('tryParse returns null instead of throwing', () {
    expect(EntityRef.tryParse('garbage'), isNull);
    expect(EntityRef.tryParse('node:n_1')?.id, 'n_1');
  });
}
