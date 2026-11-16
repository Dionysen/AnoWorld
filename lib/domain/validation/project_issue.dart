enum ProjectIssueSeverity { error, warning }

class ProjectIssue {
  const ProjectIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.path = r'$project',
  });

  final ProjectIssueSeverity severity;
  final String code;
  final String message;
  final String path;

  bool get isError => severity == ProjectIssueSeverity.error;

  @override
  String toString() => '$path [$code]: $message';
}

class ProjectValidationResult {
  const ProjectValidationResult(this.issues);

  final List<ProjectIssue> issues;

  bool get hasErrors => issues.any((i) => i.isError);

  bool get isPlayable => !hasErrors;

  List<ProjectIssue> get errors =>
      issues.where((i) => i.isError).toList(growable: false);

  List<ProjectIssue> get warnings => issues
      .where((i) => i.severity == ProjectIssueSeverity.warning)
      .toList(growable: false);
}
