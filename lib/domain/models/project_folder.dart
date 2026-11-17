/// A user folder grouping works in the library browser.
class ProjectFolder {
  const ProjectFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.sortOrder = 0,
    required this.createdAt,
    this.projectCount = 0,
    this.childFolderCount = 0,
  });

  final String id;
  final String name;

  /// null = top-level under the library root.
  final String? parentId;
  final int sortOrder;
  final DateTime createdAt;

  /// Direct member works (display only).
  final int projectCount;

  /// Direct child folders (display only).
  final int childFolderCount;

  ProjectFolder copyWith({
    String? id,
    String? name,
    String? parentId,
    bool clearParentId = false,
    int? sortOrder,
    DateTime? createdAt,
    int? projectCount,
    int? childFolderCount,
  }) =>
      ProjectFolder(
        id: id ?? this.id,
        name: name ?? this.name,
        parentId: clearParentId ? null : (parentId ?? this.parentId),
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        projectCount: projectCount ?? this.projectCount,
        childFolderCount: childFolderCount ?? this.childFolderCount,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        if (parentId != null) 'parentId': parentId,
        'sortOrder': sortOrder,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory ProjectFolder.fromJson(Map<String, dynamic> json) {
    return ProjectFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parentId'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
