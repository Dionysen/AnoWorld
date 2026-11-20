import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/domain/validation/project_validator.dart';
import 'package:anoworld/foundation/text/rich_text_sanitizer.dart';

/// Everything the create tools may lean on.
///
/// Read tools only touch [CreateToolContext.project]; the transport is only
/// needed by the assistant loop.
class CreateToolServices {
  const CreateToolServices({
    this.toolClient,
    this.validator = const ProjectValidator(),
    this.sanitizer = const RichTextSanitizer(),
    this.plotCatalog,
  });

  /// Tool-calling transport; null when the active client cannot run tool turns.
  final AiToolTurnClient? toolClient;

  final ProjectValidator validator;
  final RichTextSanitizer sanitizer;

  /// Selected plot elements are woven into create prompts when available.
  final PlotElementCatalog? plotCatalog;
}
