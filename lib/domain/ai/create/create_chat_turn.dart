/// One earlier line of the create-assistant conversation.
///
/// Only text is kept: tool calls and their results belong to a single turn and
/// are never replayed across turns. The panel passes what the user can see, so
/// "再冷一点" has something to refer back to.
class CreateChatTurn {
  const CreateChatTurn._({required this.fromUser, required this.text});

  const CreateChatTurn.user(String text)
      : this._(fromUser: true, text: text);

  const CreateChatTurn.assistant(String text)
      : this._(fromUser: false, text: text);

  final bool fromUser;
  final String text;
}
