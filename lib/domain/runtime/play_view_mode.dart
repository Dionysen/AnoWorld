/// How a play session presents the shared Main runtime.
///
/// Chosen when starting play; locked for that session (and remembered in saves).
enum PlayViewMode {
  visualNovel,
  chat,
}

extension PlayViewModeCodec on PlayViewMode {
  String get wireName => name;

  static PlayViewMode parse(String? raw) {
    if (raw == 'chat') return PlayViewMode.chat;
    return PlayViewMode.visualNovel;
  }
}
