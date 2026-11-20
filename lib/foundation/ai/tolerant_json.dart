import 'dart:convert';

/// Decodes JSON emitted by a model, repairing the failure that wrecks long
/// Chinese tool arguments: an unescaped `"` used as an in-sentence quote.
///
/// Models routinely send
///
/// ```json
/// {"synopsis": "同门唤他"扫地的"，连杂役峰都劝他早些下山。"}
/// ```
///
/// which is not JSON. Strict input is decoded untouched; anything else is only
/// accepted when the repaired text parses, so a different shape still fails.
Object? decodeTolerantJson(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    // Fall through: repair, then let the parse decide.
  }
  final repaired = repairJsonStringQuotes(text);
  if (repaired == text) return null;
  try {
    return jsonDecode(repaired);
  } on FormatException {
    return null;
  }
}

/// Escapes stray `"` and raw line breaks inside string values.
///
/// A quote only closes a string where JSON expects a delimiter (`,`, `:`, `}`,
/// `]`); every other quote inside a value is a typographic quote and gets
/// escaped. Existing escapes (`\"`, `\n`, …) are copied verbatim.
String repairJsonStringQuotes(String raw) {
  final out = StringBuffer();
  var inString = false;
  for (var i = 0; i < raw.length; i++) {
    final unit = raw.codeUnitAt(i);
    if (!inString) {
      if (unit == _quote) inString = true;
      out.writeCharCode(unit);
      continue;
    }
    if (unit == _backslash) {
      out.writeCharCode(unit);
      if (i + 1 < raw.length) {
        out.writeCharCode(raw.codeUnitAt(i + 1));
        i++;
      }
      continue;
    }
    if (unit == _quote) {
      if (_closesString(raw, i + 1)) {
        inString = false;
        out.writeCharCode(unit);
      } else {
        out.write(r'\"');
      }
      continue;
    }
    if (unit == _newline) {
      out.write(r'\n');
      continue;
    }
    if (unit == _carriageReturn) {
      out.write(r'\r');
      continue;
    }
    if (unit == _tab) {
      out.write(r'\t');
      continue;
    }
    out.writeCharCode(unit);
  }
  return out.toString();
}

const int _quote = 0x22;
const int _backslash = 0x5C;
const int _comma = 0x2C;
const int _colon = 0x3A;
const int _closeBrace = 0x7D;
const int _closeBracket = 0x5D;
const int _newline = 0x0A;
const int _carriageReturn = 0x0D;
const int _tab = 0x09;

/// True when the first non-space after [from] is a JSON delimiter (or input
/// ends), i.e. the quote really was the end of the value.
bool _closesString(String raw, int from) {
  for (var i = from; i < raw.length; i++) {
    final unit = raw.codeUnitAt(i);
    if (unit == 0x20 || unit == _newline || unit == _carriageReturn || unit == _tab) {
      continue;
    }
    return unit == _comma ||
        unit == _colon ||
        unit == _closeBrace ||
        unit == _closeBracket;
  }
  return true;
}
