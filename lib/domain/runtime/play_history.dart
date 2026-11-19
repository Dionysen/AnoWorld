import 'package:anoworld/domain/models/main_story.dart';

/// VN position timeline: one entry per **line** the player has reached.
///
/// An entry carries the phase it was left in (`lines` / `choices` / …), but the
/// phase is a property of that line, not an extra step — so stepping back from
/// a choices prompt lands on the *previous* line, and pressing forward at the
/// newest progress never reports "nothing recorded" just because the prompt is
/// the same line.
///
/// Advancing from the past reuses a matching forward entry, so replaying never
/// duplicates the timeline; a genuinely new destination truncates what came
/// after it.
class PlayHistory {
  PlayHistory({
    List<MainSavePointer> entries = const <MainSavePointer>[],
    int cursor = -1,
  })  : entries = List<MainSavePointer>.from(entries),
        cursor = entries.isEmpty ? -1 : cursor.clamp(0, entries.length - 1);

  final List<MainSavePointer> entries;

  /// Index into [entries]; `-1` when nothing has been recorded yet.
  int cursor;

  bool get isEmpty => entries.isEmpty;

  bool get canBack => cursor > 0;

  bool get canForward => cursor >= 0 && cursor < entries.length - 1;

  /// Newest progress recorded for this slot (may be a not-yet-generated point).
  bool get atLatest => entries.isEmpty || cursor >= entries.length - 1;

  MainSavePointer? get current =>
      cursor >= 0 && cursor < entries.length ? entries[cursor] : null;

  /// Records [pointer] as the newest current position.
  void record(MainSavePointer pointer) {
    if (entries.isEmpty) {
      entries.add(pointer);
      cursor = 0;
      return;
    }
    final active = cursor.clamp(0, entries.length - 1);
    if (_sameLine(entries[active], pointer)) {
      // Same line, new phase (choices / needsBridge / ended): keep one entry.
      entries[active] = pointer;
      cursor = active;
      return;
    }
    // Replaying forward: reuse the existing entry and drop stale in-betweens.
    for (var i = active + 1; i < entries.length; i++) {
      if (_sameLine(entries[i], pointer)) {
        entries[i] = pointer;
        entries.removeRange(active + 1, i);
        cursor = active + 1;
        return;
      }
    }
    entries.removeRange(active + 1, entries.length);
    entries.add(pointer);
    cursor = entries.length - 1;
  }

  MainSavePointer? stepBack() {
    if (!canBack) return null;
    cursor -= 1;
    return entries[cursor];
  }

  MainSavePointer? stepForward() {
    if (!canForward) return null;
    cursor += 1;
    return entries[cursor];
  }

  /// Jump to the newest recorded position (fast-forward stop point).
  MainSavePointer? jumpToLatest() {
    if (atLatest) return null;
    cursor = entries.length - 1;
    return entries[cursor];
  }

  void clear() {
    entries.clear();
    cursor = -1;
  }

  /// Line identity: the phase of the same line is not a separate position.
  static bool _sameLine(MainSavePointer a, MainSavePointer b) =>
      a.nodeId == b.nodeId &&
      a.beatId == b.beatId &&
      a.lineIndex == b.lineIndex;
}
