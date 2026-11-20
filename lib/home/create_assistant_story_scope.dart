import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/home/create_assistant_controller.dart';
import 'package:flutter/widgets.dart';

/// Points the create assistant at the story this edit page belongs to.
///
/// Pages register on mount and unregister on dispose; the controller follows
/// the newest one, so opening a story's plot graph / world book / cast switches
/// the assistant to that story and going back falls to the page underneath.
/// The user can still pick another story by hand in the panel.
mixin CreateAssistantStoryScope<T extends StatefulWidget> on State<T> {
  CreateAssistantController? _assistant;
  String? _registeredId;

  /// Story this page edits.
  String get assistantStoryId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final assistant = AppScope.createAssistantOf(context);
    if (!identical(_assistant, assistant)) {
      _assistant?.leaveStory(this);
      _assistant = assistant;
      _registeredId = null;
    }
    final id = assistantStoryId;
    if (id.isEmpty || id == _registeredId) return;
    assistant.enterStory(this, id);
    _registeredId = id;
  }

  @override
  void dispose() {
    _assistant?.leaveStory(this);
    super.dispose();
  }
}
