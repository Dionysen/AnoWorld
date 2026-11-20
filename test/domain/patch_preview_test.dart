import 'package:anoworld/domain/main/patch_preview.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:flutter_test/flutter_test.dart';

MainStory _graph() => const MainStory(
      summary: '雨夜出城',
      startNodeId: 'n1',
      nodes: [
        StoryNode(id: 'n1', title: '客栈', beatIds: []),
        StoryNode(id: 'n2', title: '城门', beatIds: []),
      ],
      edges: [
        StoryEdge(id: 'e1', from: 'n1', to: 'n2', kind: EdgeKind.defaultEdge),
      ],
      beats: [],
    );

void main() {
  group('world book preview', () {
    const base = WorldBook(
      entries: [WorldBookEntry(id: 'wb1', title: '潮汐', body: '退潮才开城门')],
    );

    test('diffs only the fields an op actually changes', () {
      final patch = buildWorldBookPreview(base, [
        {'op': 'upsert_entry', 'id': 'wb1', 'body': '涨潮也能开'},
      ]);

      expect(patch.items, hasLength(1));
      final item = patch.items.single;
      expect(item.usable, isTrue);
      final change = item.changes.single;
      expect(change.kind, PatchTargetKind.worldBook);
      expect(change.label, '潮汐');
      expect(change.added, isFalse);
      expect(change.removed, isFalse);
      expect(change.fields, hasLength(1));
      expect(change.fields.single.field, 'body');
      expect(change.fields.single.before, '退潮才开城门');
      expect(change.fields.single.after, '涨潮也能开');
    });

    test('marks a new entry as added with its filled fields', () {
      final patch = buildWorldBookPreview(base, [
        {'op': 'upsert_entry', 'title': '守夜人', 'body': '只在夜里出现'},
      ]);

      final change = patch.items.single.changes.single;
      expect(change.added, isTrue);
      expect(change.label, '守夜人');
      expect(
        change.fields.map((f) => f.field),
        containsAll(<String>['title', 'body']),
      );
    });

    test('default selection skips ops that change nothing', () {
      final patch = buildWorldBookPreview(base, [
        {'op': 'upsert_entry', 'id': 'wb1', 'body': '退潮才开城门'},
        {'op': 'upsert_entry', 'id': 'wb1', 'body': '涨潮也能开'},
      ]);

      expect(patch.items.first.hasChanges, isFalse);
      expect(patch.defaultSelection, {1});
      expect(
        patch.applySelected(patch.defaultSelection).entries.single.body,
        '涨潮也能开',
      );
    });

    test('a broken op keeps its error and is not selected', () {
      final patch = buildWorldBookPreview(base, [
        {'op': 'remove_entry', 'id': 'missing'},
        {'op': 'upsert_entry', 'id': 'wb1', 'body': '涨潮也能开'},
      ]);

      expect(patch.items.first.error, isNotNull);
      expect(patch.items.first.usable, isFalse);
      expect(patch.defaultSelection, {1});
    });
  });

  group('cast preview', () {
    const base = [CastMember(id: 'c1', name: '阿岚', summary: '客栈老板')];

    test('reports the renamed entity with before and after', () {
      final patch = buildCastPreview(base, [
        {'op': 'upsert_member', 'id': 'c1', 'name': '阿岚·夜'},
      ]);

      final change = patch.items.single.changes.single;
      expect(change.kind, PatchTargetKind.cast);
      expect(change.fields.single.field, 'name');
      expect(change.fields.single.before, '阿岚');
      expect(change.fields.single.after, '阿岚·夜');
    });

    test('remove_member shows up as removed', () {
      final patch = buildCastPreview(base, [
        {'op': 'remove_member', 'id': 'c1'},
      ]);

      final change = patch.items.single.changes.single;
      expect(change.removed, isTrue);
      expect(change.label, '阿岚');
      expect(patch.applySelected({0}), isEmpty);
    });
  });

  group('main graph preview', () {
    test('removing a node also reports the edges it takes with it', () {
      final patch = buildMainGraphPreview(_graph(), [
        {'op': 'remove_node', 'id': 'n1'},
      ]);

      final item = patch.items.single;
      expect(item.changes, hasLength(2));
      expect(item.changes.first.kind, PatchTargetKind.node);
      expect(item.changes.first.removed, isTrue);
      expect(item.changes.last.kind, PatchTargetKind.edge);
      expect(item.changes.last.removed, isTrue);
      expect(item.changes.last.label, '客栈 → 城门');
    });

    test('set_summary surfaces as a summary field change', () {
      final patch = buildMainGraphPreview(_graph(), [
        {'op': 'set_summary', 'summary': '今夜必须出城'},
      ]);

      final change = patch.items.single.changes.single;
      expect(change.kind, PatchTargetKind.storySummary);
      expect(change.fields.single.field, 'storySummary');
      expect(change.fields.single.before, '雨夜出城');
      expect(change.fields.single.after, '今夜必须出城');
    });

    test('applying a subset keeps only the ticked ops', () {
      final patch = buildMainGraphPreview(_graph(), [
        {'op': 'set_summary', 'summary': '今夜必须出城'},
        {'op': 'upsert_node', 'id': 'n3', 'title': '渡口'},
      ]);

      final onlyNode = patch.applySelected({1});
      expect(onlyNode.summary, '雨夜出城');
      expect(onlyNode.nodes.map((n) => n.id), contains('n3'));

      final onlySummary = patch.applySelected({0});
      expect(onlySummary.summary, '今夜必须出城');
      expect(onlySummary.nodes.map((n) => n.id), isNot(contains('n3')));
    });

    test('a broken edge reference is reported instead of thrown', () {
      final patch = buildMainGraphPreview(_graph(), [
        {'op': 'upsert_edge', 'from': 'n1', 'to': 'nowhere'},
      ]);

      expect(patch.items.single.error, isNotNull);
      expect(patch.defaultSelection, isEmpty);
    });
  });
}
