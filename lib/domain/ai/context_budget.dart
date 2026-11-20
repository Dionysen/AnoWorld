import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/text/token_estimator.dart';

/// Input-token budget for one model request: `contextLength − maxTokens`.
///
/// This is the only place that turns the 上下文长度 slider into a trimming
/// decision. The built-in presets ship a 1M window, so nothing is dropped by
/// default; a 4k window keeps only the newest turns of the scene.
class ContextBudget {
  const ContextBudget({required this.inputTokens});

  /// Never trim below this, even when the preset reserves more output than
  /// the window itself (4k context with 8k max output is a real slider pair).
  static const int minInputTokens = 2048;

  /// Input tokens the request may spend.
  final int inputTokens;

  factory ContextBudget.of(GenerationPreset generation) {
    final input = generation.contextLength - generation.maxTokens;
    return ContextBudget(
      inputTokens: input < minInputTokens ? minInputTokens : input,
    );
  }

  int estimate(String text) => TokenEstimator.estimate(text);

  /// Tokens left after [usedTokens] of fixed prompt text; never negative.
  int remaining(int usedTokens) {
    final left = inputTokens - usedTokens;
    return left < 0 ? 0 : left;
  }

  /// Newest [items] that fit in [tokens]; older items are dropped first.
  ///
  /// [minItems] always keeps that many newest items even when they overflow,
  /// so a reply is never written against an empty transcript.
  List<T> keepNewest<T>(
    List<T> items,
    String Function(T) textOf, {
    required int tokens,
    int minItems = 0,
  }) {
    var used = 0;
    var start = items.length;
    while (start > 0) {
      final cost = estimate(textOf(items[start - 1]));
      if (used + cost > tokens) break;
      used += cost;
      start--;
    }
    final floor = minItems.clamp(0, items.length);
    if (items.length - start < floor) start = items.length - floor;
    return items.sublist(start);
  }

  /// Tail of [text] that fits in [tokens]; the head is dropped.
  ///
  /// Cuts on a nearby space / newline when one is close, so a Japanese or
  /// English summary does not start mid-word. Chinese has no spaces, so a
  /// mid-sentence start is accepted there.
  String keepTail(String text, {required int tokens}) {
    if (text.isEmpty) return text;
    if (estimate(text) <= tokens) return text;
    if (tokens <= 0) return '';
    final runes = text.runes.toList(growable: false);
    var weight = 0.0;
    var start = runes.length;
    while (start > 0) {
      final rune = runes[start - 1];
      final cost = rune < 0x80 ? 1 / TokenEstimator.asciiCharsPerToken : 1.0;
      if (weight + cost > tokens) break;
      weight += cost;
      start--;
    }
    const maxSkip = 24;
    for (var i = start; i < runes.length && i - start < maxSkip; i++) {
      if (_isSpace(runes[i])) {
        start = i + 1;
        break;
      }
    }
    return String.fromCharCodes(runes.sublist(start)).trim();
  }

  static bool _isSpace(int rune) =>
      rune == 0x20 || rune == 0x0A || rune == 0x0D || rune == 0x09;
}
