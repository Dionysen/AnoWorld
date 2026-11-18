import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_result.dart';

typedef CreateToolInvoke =
    Future<CreateToolResult> Function(CreateToolContext ctx, Map<String, dynamic> args);

class CreateTool {
  const CreateTool({
    required this.name,
    required this.description,
    required this.mutatesProject,
    required this.invoke,
  });

  final String name;
  final String description;
  final bool mutatesProject;
  final CreateToolInvoke invoke;
}