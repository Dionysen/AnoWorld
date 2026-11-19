import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blank project has empty plot element selection and schema v3', () {
    final project = const ProjectFactory().createBlank(
      id: 'p1',
      title: '测',
      now: DateTime.utc(2026, 1, 1),
    );
    expect(project.plotElements.selectedIds, isEmpty);
    expect(project.meta.schemaVersion, 3);
  });

  test('plotElements selectedIds round-trip in project json', () {
    final blank = const ProjectFactory().createBlank(
      id: 'p2',
      title: '测',
      now: DateTime.utc(2026, 1, 2),
    );
    final stamped = blank.copyWith(
      plotElements: const PlotElementSelection(
        selectedIds: <String>['pe_stray_cat', 'pe_missing'],
      ),
    );
    final restored = Project.fromJson(stamped.toJson());
    expect(restored.plotElements.selectedIds, [
      'pe_stray_cat',
      'pe_missing',
    ]);
  });

  test('Project.fromJson tolerates missing plotElements', () {
    final blank = const ProjectFactory().createBlank(
      id: 'p3',
      title: '旧包',
      now: DateTime.utc(2026, 1, 3),
    );
    final map = blank.toJson()..remove('plotElements');
    final project = Project.fromJson(map);
    expect(project.plotElements.isEmpty, isTrue);
  });
}
