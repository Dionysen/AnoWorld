import 'package:anoworld/domain/models/json_map.dart';

/// One group of plot elements in the global library (日常、危机…).
class PlotElementCategory {
  const PlotElementCategory({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};

  factory PlotElementCategory.fromJson(Map<String, dynamic> json) {
    return PlotElementCategory(
      id: json.requireString('id'),
      name: json.requireString('name').trim(),
    );
  }

  PlotElementCategory copyWith({String? name}) {
    return PlotElementCategory(id: id, name: name ?? this.name);
  }
}
