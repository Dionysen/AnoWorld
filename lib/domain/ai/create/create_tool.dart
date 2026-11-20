import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';

typedef CreateToolInvoke = Future<CreateToolResult> Function(
    CreateToolContext ctx, Map<String, dynamic> args);

/// One tool the create assistant may call.
///
/// [parameters] is a JSON Schema object; empty means "takes no arguments".
class CreateTool {
  const CreateTool({
    required this.name,
    required this.description,
    required this.mutatesProject,
    required this.invoke,
    this.parameters = const <String, dynamic>{},
  });

  final String name;
  final String description;
  final bool mutatesProject;
  final CreateToolInvoke invoke;

  /// JSON Schema for the arguments, sent to the model as the function params.
  final Map<String, dynamic> parameters;

  /// Name safe to send as `tools[].function.name`.
  ///
  /// OpenAI-compatible providers only accept `[a-zA-Z0-9_-]`, so the canonical
  /// dotted name (`world.patch`) travels as `world_patch`. The registry maps it
  /// back, so prompts and logs keep the readable form.
  String get wireName => wireNameOf(name);

  static String wireNameOf(String name) =>
      name.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');

  /// Declaration handed to the model; always an object schema.
  OpenAiTool declaration() => OpenAiTool(
        name: wireName,
        description: description,
        parameters: parameters.isEmpty ? objectSchema() : parameters,
      );
}

/// `{"type":"object","properties":{...}}`, the shape every tool needs.
Map<String, dynamic> objectSchema([
  Map<String, dynamic> properties = const <String, dynamic>{},
  List<String> required = const <String>[],
]) =>
    <String, dynamic>{
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    };

/// `{"type":"string"}` with an optional hint for the model.
Map<String, dynamic> stringSchema(String description) => <String, dynamic>{
      'type': 'string',
      'description': description,
    };

/// `{"type":"integer"}` with an optional hint for the model.
Map<String, dynamic> integerSchema(String description) => <String, dynamic>{
      'type': 'integer',
      'description': description,
    };

/// `{"type":"array","items":...}`.
Map<String, dynamic> arraySchema(
  Map<String, dynamic> items, {
  String description = '',
}) =>
    <String, dynamic>{
      'type': 'array',
      if (description.isNotEmpty) 'description': description,
      'items': items,
    };
