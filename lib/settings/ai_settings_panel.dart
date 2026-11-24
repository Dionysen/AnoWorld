import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/ai/ai_model_catalog.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_edit_tile.dart';
import 'package:anoworld/settings/ai_model_picker.dart';
import 'package:flutter/material.dart';

/// Text and image API endpoints (provider, address, key, model).
///
/// Image quality and visual-novel direction live on [GenerationSettingsPanel].
class AiSettingsPanel extends StatefulWidget {
  const AiSettingsPanel({super.key});

  @override
  State<AiSettingsPanel> createState() => _AiSettingsPanelState();
}

class _AiSettingsPanelState extends State<AiSettingsPanel> {
  Future<void> _persist(AiSettings next) async {
    await AppScope.settingsOf(context).updateAi(next);
  }

  Future<T?> _pickProvider<T>({
    required T current,
    required List<T> options,
    required String Function(T) labelOf,
    required String Function(T) urlOf,
  }) {
    return showAppSheet<T>(
      context: context,
      size: AppSheetSize.half,
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.spaceXs,
                AppTheme.pagePadding,
                0,
              ),
              child: AppSectionHeader(
                context.strings.pickProviderTitle,
                subtitle: context.strings.pickProviderHint,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  0,
                  0,
                  AppTheme.spaceMd,
                ),
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  final option = options[index];
                  return AppListTile(
                    title: labelOf(option),
                    subtitle: urlOf(option),
                    icon: Icons.dns_outlined,
                    onTap: () => Navigator.of(context).pop(option),
                    trailing: option == current
                        ? AppText(
                            context.strings.currentTag,
                            role: AppTextRole.caption,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    final catalog = AppScope.modelCatalogOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ai = controller.ai;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TextChannelEditor(
              endpoint: ai.text,
              catalog: catalog,
              onPickKind: () async {
                final kind = await _pickProvider<AiTextProviderKind>(
                  current: ai.text.kind,
                  options: AiTextProviderKind.values,
                  labelOf: (k) => context.strings.textProviderName(k),
                  urlOf: (k) => k.defaultBaseUrl,
                );
                if (kind == null || !mounted) return;
                await _persist(ai.switchTextKind(kind));
              },
              onChanged: (endpoint) => _persist(ai.withText(endpoint)),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            _ImageChannelEditor(
              endpoint: ai.image,
              catalog: catalog,
              onPickKind: () async {
                final kind = await _pickProvider<AiImageProviderKind>(
                  current: ai.image.kind,
                  options: AiImageProviderKind.values,
                  labelOf: (k) => context.strings.imageProviderName(k),
                  urlOf: (k) => k.defaultBaseUrl,
                );
                if (kind == null || !mounted) return;
                await _persist(ai.switchImageKind(kind));
              },
              onChanged: (endpoint) => _persist(ai.withImage(endpoint)),
            ),
          ],
        );
      },
    );
  }
}

class _TextChannelEditor extends StatefulWidget {
  const _TextChannelEditor({
    required this.endpoint,
    required this.catalog,
    required this.onPickKind,
    required this.onChanged,
  });

  final AiTextEndpoint endpoint;
  final AiModelCatalog catalog;
  final VoidCallback onPickKind;
  final ValueChanged<AiTextEndpoint> onChanged;

  @override
  State<_TextChannelEditor> createState() => _TextChannelEditorState();
}

class _TextChannelEditorState extends State<_TextChannelEditor> {
  AiTextProviderKind? _boundKind;
  List<String> _models = const [];
  bool _probing = false;
  String? _probeStatus;
  Timer? _probeDebounce;
  String? _lastProbedSignature;

  @override
  void initState() {
    super.initState();
    _boundKind = widget.endpoint.kind;
    // Probe after first frame so context.strings is safe (not during initState).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleAutoProbe(immediate: true);
    });
  }

  @override
  void didUpdateWidget(covariant _TextChannelEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.endpoint.kind != _boundKind) {
      _boundKind = widget.endpoint.kind;
      _models = const [];
      _probeStatus = null;
      _lastProbedSignature = null;
      _scheduleAutoProbe(immediate: true);
    } else if (widget.endpoint.baseUrl != oldWidget.endpoint.baseUrl ||
        widget.endpoint.apiKey != oldWidget.endpoint.apiKey) {
      _scheduleAutoProbe(immediate: true);
    }
  }

  @override
  void dispose() {
    _probeDebounce?.cancel();
    super.dispose();
  }

  AiTextEndpoint get _endpoint => widget.endpoint;

  String get _probeSignature {
    final d = _endpoint;
    final base = d.baseUrl.isEmpty ? d.kind.defaultBaseUrl : d.baseUrl;
    return '${d.kind.name}|$base|${d.apiKey}';
  }

  bool get _canProbe {
    final d = _endpoint;
    final base =
        (d.baseUrl.isEmpty ? d.kind.defaultBaseUrl : d.baseUrl).trim();
    if (base.isEmpty) return false;
    if (d.needsApiKey && d.apiKey.isEmpty) return false;
    return true;
  }

  void _scheduleAutoProbe({bool immediate = false}) {
    _probeDebounce?.cancel();
    if (!_canProbe) return;
    if (immediate) {
      unawaited(_probeModels());
      return;
    }
    _probeDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_probeModels());
    });
  }

  Future<void> _probeModels({bool force = false}) async {
    if (!_canProbe) {
      setState(() {
        _probeStatus = widget.endpoint.needsApiKey
            ? context.strings.probeHintNeedsKey
            : context.strings.probeHintNoKey;
      });
      return;
    }
    final signature = _probeSignature;
    if (!force && signature == _lastProbedSignature && _models.isNotEmpty) {
      return;
    }
    setState(() {
      _probing = true;
      _probeStatus = context.strings.probingModels;
    });
    try {
      final models = await widget.catalog
          .listModels(AiEndpointConfig.fromText(_endpoint));
      if (!mounted) return;
      final shouldPickDefault =
          widget.endpoint.model.trim().isEmpty && models.isNotEmpty;
      setState(() {
        _models = models;
        _probing = false;
        _lastProbedSignature = signature;
        _probeStatus = context.strings.foundModels(models.length);
      });
      if (shouldPickDefault) {
        widget.onChanged(_endpoint.copyWith(model: models.first));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _probing = false;
        _probeStatus = error is AiModelCatalogException
            ? error.message
            : context.strings.probeFailed(error);
      });
    }
  }

  Future<void> _pickModel() async {
    if (_models.isEmpty && !_probing) {
      await _probeModels(force: true);
    }
    if (!mounted || _models.isEmpty) return;
    final selected = await showAiModelSheet(
      context,
      models: _models,
      current: widget.endpoint.model,
    );
    if (selected == null || !mounted) return;
    widget.onChanged(_endpoint.copyWith(model: selected));
  }

  Future<void> _pickReasoningEffort() async {
    final selected = await showAiReasoningEffortSheet(
      context,
      current: widget.endpoint.reasoningEffort,
    );
    if (selected == null || !mounted) return;
    widget.onChanged(_endpoint.copyWith(reasoningEffort: selected));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _ChannelScaffold(
      title: strings.textChannelTitle,
      caption: strings.textChannelHint,
      providerLabel: strings.textProviderName(widget.endpoint.kind),
      onPickKind: widget.onPickKind,
      baseUrl: widget.endpoint.baseUrl,
      apiKey: widget.endpoint.apiKey,
      defaultBaseUrl: widget.endpoint.kind.defaultBaseUrl,
      needsApiKey: widget.endpoint.needsApiKey,
      model: widget.endpoint.model,
      modelHint: _modelHint(
        strings,
        widget.endpoint.model,
        _probing,
        _models,
      ),
      probing: _probing,
      probeStatus: _probeStatus,
      reasoningEffortLabel: strings.reasoningEffortName(
        widget.endpoint.reasoningEffort,
      ),
      onPickReasoningEffort: _pickReasoningEffort,
      onBaseSubmitted: (value) {
        widget.onChanged(_endpoint.copyWith(baseUrl: value));
      },
      onKeySubmitted: (value) {
        widget.onChanged(_endpoint.copyWith(apiKey: value));
      },
      onPickModel: _probing ? null : _pickModel,
      onProbe: _probing ? null : () => _probeModels(force: true),
    );
  }
}

class _ImageChannelEditor extends StatefulWidget {
  const _ImageChannelEditor({
    required this.endpoint,
    required this.catalog,
    required this.onPickKind,
    required this.onChanged,
  });

  final AiImageEndpoint endpoint;
  final AiModelCatalog catalog;
  final VoidCallback onPickKind;
  final ValueChanged<AiImageEndpoint> onChanged;

  @override
  State<_ImageChannelEditor> createState() => _ImageChannelEditorState();
}

class _ImageChannelEditorState extends State<_ImageChannelEditor> {
  AiImageProviderKind? _boundKind;
  List<String> _models = const [];
  bool _probing = false;
  String? _probeStatus;
  Timer? _probeDebounce;
  String? _lastProbedSignature;

  @override
  void initState() {
    super.initState();
    _boundKind = widget.endpoint.kind;
    // Probe after first frame so context.strings is safe (not during initState).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleAutoProbe(immediate: true);
    });
  }

  @override
  void didUpdateWidget(covariant _ImageChannelEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.endpoint.kind != _boundKind) {
      _boundKind = widget.endpoint.kind;
      _models = const [];
      _probeStatus = null;
      _lastProbedSignature = null;
      _scheduleAutoProbe(immediate: true);
    } else if (widget.endpoint.baseUrl != oldWidget.endpoint.baseUrl ||
        widget.endpoint.apiKey != oldWidget.endpoint.apiKey) {
      _scheduleAutoProbe(immediate: true);
    }
  }

  @override
  void dispose() {
    _probeDebounce?.cancel();
    super.dispose();
  }

  AiImageEndpoint get _endpoint => widget.endpoint;

  String get _probeSignature {
    final d = _endpoint;
    final base = d.baseUrl.isEmpty ? d.kind.defaultBaseUrl : d.baseUrl;
    return '${d.kind.name}|$base|${d.apiKey}';
  }

  bool get _canProbe {
    final d = _endpoint;
    final base =
        (d.baseUrl.isEmpty ? d.kind.defaultBaseUrl : d.baseUrl).trim();
    if (d.kind.supportsModelProbe) {
      if (base.isEmpty) return false;
      if (d.needsApiKey && d.apiKey.isEmpty) return false;
      return true;
    }
    return d.kind.fallbackModels.isNotEmpty;
  }

  void _scheduleAutoProbe({bool immediate = false}) {
    _probeDebounce?.cancel();
    if (!_canProbe) return;
    if (immediate) {
      unawaited(_probeModels());
      return;
    }
    _probeDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_probeModels());
    });
  }

  Future<void> _probeModels({bool force = false}) async {
    if (!_canProbe) {
      setState(() {
        _probeStatus = widget.endpoint.needsApiKey
            ? context.strings.probeHintNeedsKey
            : context.strings.probeHintManual;
      });
      return;
    }
    final signature = _probeSignature;
    if (!force && signature == _lastProbedSignature && _models.isNotEmpty) {
      return;
    }
    setState(() {
      _probing = true;
      _probeStatus = context.strings.probingModels;
    });
    try {
      List<String> models;
      if (widget.endpoint.supportsModelProbe) {
        models = await widget.catalog
            .listModels(AiEndpointConfig.fromImage(_endpoint));
      } else {
        models = List<String>.from(widget.endpoint.kind.fallbackModels);
      }
      if (!mounted) return;
      final shouldPickDefault =
          widget.endpoint.model.trim().isEmpty && models.isNotEmpty;
      setState(() {
        _models = models;
        _probing = false;
        _lastProbedSignature = signature;
        _probeStatus = context.strings.foundModels(models.length);
      });
      if (shouldPickDefault) {
        widget.onChanged(_endpoint.copyWith(model: models.first));
      }
    } catch (error) {
      if (!mounted) return;
      final fallback = widget.endpoint.kind.fallbackModels;
      if (fallback.isNotEmpty) {
        setState(() {
          _models = fallback;
          _probing = false;
          _lastProbedSignature = signature;
          _probeStatus = context.strings.probeFallbackModels;
        });
        return;
      }
      setState(() {
        _probing = false;
        _probeStatus = error is AiModelCatalogException
            ? error.message
            : context.strings.probeFailed(error);
      });
    }
  }

  Future<void> _pickModel() async {
    if (_models.isEmpty && !_probing) {
      await _probeModels(force: true);
    }
    if (!mounted || _models.isEmpty) return;
    final selected = await showAiModelSheet(
      context,
      models: _models,
      current: widget.endpoint.model,
    );
    if (selected == null || !mounted) return;
    widget.onChanged(_endpoint.copyWith(model: selected));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _ChannelScaffold(
      title: strings.imageChannelTitle,
      caption: strings.imageChannelHint,
      providerLabel: strings.imageProviderName(widget.endpoint.kind),
      onPickKind: widget.onPickKind,
      baseUrl: widget.endpoint.baseUrl,
      apiKey: widget.endpoint.apiKey,
      defaultBaseUrl: widget.endpoint.kind.defaultBaseUrl,
      needsApiKey: widget.endpoint.needsApiKey,
      model: widget.endpoint.model,
      modelHint: _modelHint(
        strings,
        widget.endpoint.model,
        _probing,
        _models,
      ),
      probing: _probing,
      probeStatus: _probeStatus,
      onBaseSubmitted: (value) {
        widget.onChanged(_endpoint.copyWith(baseUrl: value));
      },
      onKeySubmitted: (value) {
        widget.onChanged(_endpoint.copyWith(apiKey: value));
      },
      onPickModel: _probing ? null : _pickModel,
      onProbe: _probing ? null : () => _probeModels(force: true),
    );
  }
}

class _ChannelScaffold extends StatelessWidget {
  const _ChannelScaffold({
    required this.title,
    required this.caption,
    required this.providerLabel,
    required this.onPickKind,
    required this.baseUrl,
    required this.apiKey,
    required this.defaultBaseUrl,
    required this.needsApiKey,
    required this.model,
    required this.modelHint,
    required this.probing,
    required this.probeStatus,
    required this.onBaseSubmitted,
    required this.onKeySubmitted,
    required this.onPickModel,
    required this.onProbe,
    this.reasoningEffortLabel,
    this.onPickReasoningEffort,
  });

  final String title;
  final String caption;
  final String providerLabel;
  final VoidCallback onPickKind;
  final String baseUrl;
  final String apiKey;
  final String defaultBaseUrl;
  final bool needsApiKey;
  final String model;
  final String? modelHint;
  final bool probing;
  final String? probeStatus;
  final ValueChanged<String> onBaseSubmitted;
  final ValueChanged<String> onKeySubmitted;
  final VoidCallback? onPickModel;
  final VoidCallback? onProbe;
  final String? reasoningEffortLabel;
  final VoidCallback? onPickReasoningEffort;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final modelTrailing = model.trim().isEmpty
        ? (modelHint ?? strings.modelNotChosen)
        : model.trim();
    final showEffort = onPickReasoningEffort != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title, gutter: true),
        AppPageGutter(
          child: AppText(caption, role: AppTextRole.caption),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        AppListTile(
          title: providerLabel,
          subtitle: strings.currentProvider,
          icon: Icons.cloud_outlined,
          onTap: onPickKind,
          trailing: AppText(
            strings.changeAction,
            role: AppTextRole.caption,
          ),
        ),
        AppTextEditTile(
          title: strings.baseUrlLabel,
          subtitle: strings.baseUrlHint,
          icon: Icons.link_outlined,
          value: baseUrl,
          hint: defaultBaseUrl,
          emptyLabel: defaultBaseUrl.isEmpty
              ? strings.baseUrlEmpty
              : defaultBaseUrl,
          keyboardType: TextInputType.url,
          onSubmitted: onBaseSubmitted,
        ),
        if (needsApiKey)
          AppTextEditTile(
            title: strings.apiKeyLabel,
            subtitle: strings.apiKeyHint,
            icon: Icons.key_outlined,
            value: apiKey,
            hint: 'sk-…',
            obscureText: true,
            onSubmitted: onKeySubmitted,
          ),
        AppListTile(
          title: strings.modelLabel,
          subtitle: probing ? strings.probingShort : strings.tapToChoose,
          icon: Icons.smart_toy_outlined,
          onTap: onPickModel,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: AppText(
                  modelTrailing,
                  role: AppTextRole.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: AppTheme.spaceXs),
              const AppForwardIcon(),
            ],
          ),
        ),
        if (showEffort)
          AppListTile(
            title: strings.reasoningLabel,
            subtitle: strings.reasoningHint,
            icon: Icons.psychology_outlined,
            onTap: onPickReasoningEffort,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  reasoningEffortLabel ?? strings.reasoningEffortName(
                    AiReasoningEffort.auto,
                  ),
                  role: AppTextRole.caption,
                  maxLines: 1,
                ),
                const SizedBox(width: AppTheme.spaceXs),
                const AppForwardIcon(),
              ],
            ),
          ),
        AppListTile(
          title: probing ? strings.probeModelsRunning : strings.probeModels,
          subtitle: probeStatus ?? strings.probeModelsHint,
          icon: Icons.refresh_outlined,
          onTap: onProbe,
          showDivider: false,
        ),
      ],
    );
  }
}

String? _modelHint(
  AppStrings strings,
  String model,
  bool probing,
  List<String> models,
) {
  if (model.trim().isNotEmpty) return null;
  if (probing) return strings.probingShort;
  if (models.isEmpty) return strings.modelHintNone;
  return strings.foundModelsShort(models.length);
}
