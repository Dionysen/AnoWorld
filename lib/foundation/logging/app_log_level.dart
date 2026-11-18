enum AppLogLevel {
  info,
  warning,
  error,
}

extension AppLogLevelX on AppLogLevel {
  String get label => switch (this) {
        AppLogLevel.info => '信息',
        AppLogLevel.warning => '警告',
        AppLogLevel.error => '错误',
      };
}