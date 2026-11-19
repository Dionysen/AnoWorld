/// Rough AI token counts for text.
///
/// Calibrated against the byte-pair encoders used by current chat models
/// (`o200k_base` and comparable Claude / Gemini tokenizers): one non-ASCII
/// character costs about one token, four ASCII characters about one token.
/// Older `cl100k_base` runs ~1.4 tokens per Chinese character, so treat the
/// result as an estimate for display and context budgeting, not billing.
class TokenEstimator {
  const TokenEstimator();

  /// ASCII characters that share one token on average (English prose).
  static const int asciiCharsPerToken = 4;

  /// Estimated token count of [text]; 0 for empty input.
  static int estimate(String text) {
    if (text.isEmpty) return 0;
    var weight = 0.0;
    for (final rune in text.runes) {
      weight += rune < 0x80 ? 1 / asciiCharsPerToken : 1;
    }
    final tokens = weight.ceil();
    return tokens == 0 ? 1 : tokens;
  }
}
