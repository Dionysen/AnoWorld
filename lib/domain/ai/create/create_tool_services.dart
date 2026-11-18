import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/validation/project_validator.dart';
import 'package:anoworld/foundation/text/rich_text_sanitizer.dart';

class CreateToolServices {
  const CreateToolServices({
    required this.textClient,
    this.validator = const ProjectValidator(),
    this.sanitizer = const RichTextSanitizer(),
  });

  final AiTextClient textClient;
  final ProjectValidator validator;
  final RichTextSanitizer sanitizer;
}