/// Shared JSON helpers for hand-written codecs.
extension JsonMapRead on Map<String, dynamic> {
  String requireString(String key) {
    final value = this[key];
    if (value is String) return value;
    throw FormatException('Expected string at "$key"');
  }

  String? optionalString(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Expected string or null at "$key"');
  }

  num? optionalNum(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is num) return value;
    throw FormatException('Expected number or null at "$key"');
  }

  bool? optionalBool(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is bool) return value;
    throw FormatException('Expected bool or null at "$key"');
  }

  List<dynamic> requireList(String key) {
    final value = this[key];
    if (value is List<dynamic>) return value;
    throw FormatException('Expected list at "$key"');
  }

  List<dynamic> optionalList(String key) {
    final value = this[key];
    if (value == null) return const <dynamic>[];
    if (value is List<dynamic>) return value;
    throw FormatException('Expected list or null at "$key"');
  }

  Map<String, dynamic> requireMap(String key) {
    final value = this[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException('Expected object at "$key"');
  }

  Map<String, dynamic>? optionalMap(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException('Expected object or null at "$key"');
  }

  List<String> stringList(String key, {bool required = true}) {
    final raw = required ? requireList(key) : optionalList(key);
    return raw.map((item) {
      if (item is String) return item;
      throw FormatException('Expected string list at "$key"');
    }).toList(growable: false);
  }
}

Map<String, dynamic> asJsonMap(Object? value, {required String path}) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected object at "$path"');
}
