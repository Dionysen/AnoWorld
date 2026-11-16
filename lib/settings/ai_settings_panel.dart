import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/ai/ai_model_catalog.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_select_field.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

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
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.spaceXs,
            AppTheme.pagePadding,
            AppTheme.spaceMd,
          ),
          children: [
            const AppSectionHeader('选择供应商'),
            const SizedBox(height: AppTheme.spaceXs),
            const AppText(
              '写故事与生图请分开选择',
              role: AppTextRole.caption,
            ),
            const SizedBox(height: AppTheme.spaceGroup),
            for (final option in options) ...[
              AppListTile(
                title: labelOf(option),
                subtitle: urlOf(option),
                icon: Icons.dns_outlined,
                onTap: () => Navigator.of(context).pop(option),
                trailing: option == current
                    ? const AppText('当前', role: AppTextRole.caption)
                    : null,
              ),
              const SizedBox(height: AppTheme.spaceGroup),
            ],
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
                  labelOf: (k) => k.label,
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
                  labelOf: (k) => k.label,
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
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  AiTextProviderKind? _boundKind;
  List<String> _models = const [];
  bool _probing = false;
  String? _probeStatus;
  Timer? _probeDebounce;
  String? _lastProbedSignature;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: widget.endpoint.baseUrl);
    _apiKey = TextEditingController(text: widget.endpoint.apiKey);
    _boundKind = widget.endpoint.kind;
    _scheduleAutoProbe(immediate: true);
  }

  @override
  void didUpdateWidget(covariant _TextChannelEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.endpoint.kind != _boundKind) {
      _boundKind = widget.endpoint.kind;
      _baseUrl.text = widget.endpoint.baseUrl;
      _apiKey.text = widget.endpoint.apiKey;
      _models = const [];
      _probeStatus = null;
      _lastProbedSignature = null;
      _scheduleAutoProbe(immediate: true);
    }
  }

  @override
  void dispose() {
    _probeDebounce?.cancel();
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  AiTextEndpoint get _draft => widget.endpoint.copyWith(
        baseUrl: _baseUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
      );

  String get _probeSignature {
    final d = _draft;
    final base = d.baseUrl.isEmpty ? d.kind.defaultBaseUrl : d.baseUrl;
    return '${d.kind.name}|$base|${d.apiKey}';
  }

  bool get _canProbe {
    final d = _draft;
    final base =
        (d.baseUrl.isEmpty ? d.kind.defaultBaseUrl : d.baseUrl).trim();
    if (base.isEmpty) return false;
    if (d.needsApiKey && d.apiKey.isEmpty) return false;
    return true;
  }

  void _commitFields() => widget.onChanged(_draft);

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
            ? '填好服务地址和密钥后，会自动查找可用模型'
            : '填好服务地址后，会自动查找可用模型';
      });
      return;
    }
    final signature = _probeSignature;
    if (!force && signature == _lastProbedSignature && _models.isNotEmpty) {
      return;
    }
    setState(() {
      _probing = true;
      _probeStatus = '正在查找可用模型…';
    });
    try {
      final models =
          await widget.catalog.listModels(AiEndpointConfig.fromText(_draft));
      if (!mounted) return;
      final shouldPickDefault =
          widget.endpoint.model.trim().isEmpty && models.isNotEmpty;
      setState(() {
        _models = models;
        _probing = false;
        _lastProbedSignature = signature;
        _probeStatus = '找到 ${models.length} 个可用模型';
      });
      if (shouldPickDefault) {
        widget.onChanged(_draft.copyWith(model: models.first));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _probing = false;
        _probeStatus = error is AiModelCatalogException
            ? error.message
            : '查找失败：$error';
      });
    }
  }

  Future<void> _pickModel() async {
    if (_models.isEmpty && !_probing) {
      await _probeModels(force: true);
    }
    if (!mounted || _models.isEmpty) return;
    final selected = await _showModelSheet(
      context,
      models: _models,
      current: widget.endpoint.model,
    );
    if (selected == null || !mounted) return;
    widget.onChanged(_draft.copyWith(model: selected));
  }

  @override
  Widget build(BuildContext context) {
    return _ChannelScaffold(
      title: '文本 AI',
      caption: '写对白与剧情',
      providerLabel: widget.endpoint.kind.label,
      onPickKind: widget.onPickKind,
      baseUrl: _baseUrl,
      apiKey: _apiKey,
      defaultBaseUrl: widget.endpoint.kind.defaultBaseUrl,
      needsApiKey: widget.endpoint.needsApiKey,
      model: widget.endpoint.model,
      modelHint: _modelHint(widget.endpoint.model, _probing, _models),
      probing: _probing,
      probeStatus: _probeStatus,
      onBaseChanged: (_) => _scheduleAutoProbe(),
      onBaseComplete: () {
        _commitFields();
        _scheduleAutoProbe(immediate: true);
      },
      onKeyChanged: (_) => _scheduleAutoProbe(),
      onKeyComplete: () {
        _commitFields();
        _scheduleAutoProbe(immediate: true);
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
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  AiImageProviderKind? _boundKind;
  List<String> _models = const [];
  bool _probing = false;
  String? _probeStatus;
  Timer? _probeDebounce;
  String? _lastProbedSignature;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: widget.endpoint.baseUrl);
    _apiKey = TextEditingController(text: widget.endpoint.apiKey);
    _boundKind = widget.endpoint.kind;
    _scheduleAutoProbe(immediate: true);
  }

  @override
  void didUpdateWidget(covariant _ImageChannelEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.endpoint.kind != _boundKind) {
      _boundKind = widget.endpoint.kind;
      _baseUrl.text = widget.endpoint.baseUrl;
      _apiKey.text = widget.endpoint.apiKey;
      _models = const [];
      _probeStatus = null;
      _lastProbedSignature = null;
      _scheduleAutoProbe(immediate: true);
    }
  }

  @override
  void dispose() {
    _probeDebounce?.cancel();
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  AiImageEndpoint get _draft => widget.endpoint.copyWith(
        baseUrl: _baseUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
      );

  String get _probeSignature {
    final d = _draft;
    final base = d.baseUrl.isEmpty ? d.kind.defaultBaseUrl : d.baseUrl;
    return '${d.kind.name}|$base|${d.apiKey}';
  }

  bool get _canProbe {
    final d = _draft;
    final base =
        (d.baseUrl.isEmpty ? d.kind.defaultBaseUrl : d.baseUrl).trim();
    if (d.kind.supportsModelProbe) {
      if (base.isEmpty) return false;
      if (d.needsApiKey && d.apiKey.isEmpty) return false;
      return true;
    }
    return d.kind.fallbackModels.isNotEmpty;
  }

  void _commitFields() => widget.onChanged(_draft);

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
            ? '填好服务地址和密钥后，会自动查找可用模型'
            : '请手动填写模型，或点「查找模型」使用常用列表';
      });
      return;
    }
    final signature = _probeSignature;
    if (!force && signature == _lastProbedSignature && _models.isNotEmpty) {
      return;
    }
    setState(() {
      _probing = true;
      _probeStatus = '正在查找可用模型…';
    });
    try {
      List<String> models;
      if (widget.endpoint.supportsModelProbe) {
        models =
            await widget.catalog.listModels(AiEndpointConfig.fromImage(_draft));
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
        _probeStatus = '找到 ${models.length} 个可用模型';
      });
      if (shouldPickDefault) {
        widget.onChanged(_draft.copyWith(model: models.first));
      }
    } catch (error) {
      if (!mounted) return;
      final fallback = widget.endpoint.kind.fallbackModels;
      if (fallback.isNotEmpty) {
        setState(() {
          _models = fallback;
          _probing = false;
          _lastProbedSignature = signature;
          _probeStatus = '暂时连不上服务，已改用常用模型列表';
        });
        return;
      }
      setState(() {
        _probing = false;
        _probeStatus = error is AiModelCatalogException
            ? error.message
            : '查找失败：$error';
      });
    }
  }

  Future<void> _pickModel() async {
    if (_models.isEmpty && !_probing) {
      await _probeModels(force: true);
    }
    if (!mounted || _models.isEmpty) return;
    final selected = await _showModelSheet(
      context,
      models: _models,
      current: widget.endpoint.model,
    );
    if (selected == null || !mounted) return;
    widget.onChanged(_draft.copyWith(model: selected));
  }

  @override
  Widget build(BuildContext context) {
    return _ChannelScaffold(
      title: '生图 AI',
      caption: '生成插画，与文本分开',
      providerLabel: widget.endpoint.kind.label,
      onPickKind: widget.onPickKind,
      baseUrl: _baseUrl,
      apiKey: _apiKey,
      defaultBaseUrl: widget.endpoint.kind.defaultBaseUrl,
      needsApiKey: widget.endpoint.needsApiKey,
      model: widget.endpoint.model,
      modelHint: _modelHint(widget.endpoint.model, _probing, _models),
      probing: _probing,
      probeStatus: _probeStatus,
      onBaseChanged: (_) => _scheduleAutoProbe(),
      onBaseComplete: () {
        _commitFields();
        _scheduleAutoProbe(immediate: true);
      },
      onKeyChanged: (_) => _scheduleAutoProbe(),
      onKeyComplete: () {
        _commitFields();
        _scheduleAutoProbe(immediate: true);
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
    required this.onBaseChanged,
    required this.onBaseComplete,
    required this.onKeyChanged,
    required this.onKeyComplete,
    required this.onPickModel,
    required this.onProbe,
  });

  final String title;
  final String caption;
  final String providerLabel;
  final VoidCallback onPickKind;
  final TextEditingController baseUrl;
  final TextEditingController apiKey;
  final String defaultBaseUrl;
  final bool needsApiKey;
  final String model;
  final String? modelHint;
  final bool probing;
  final String? probeStatus;
  final ValueChanged<String> onBaseChanged;
  final VoidCallback onBaseComplete;
  final ValueChanged<String> onKeyChanged;
  final VoidCallback onKeyComplete;
  final VoidCallback? onPickModel;
  final VoidCallback? onProbe;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title),
        AppText(caption, role: AppTextRole.caption),
        const SizedBox(height: AppTheme.spaceGroup),
        AppListTile(
          title: providerLabel,
          subtitle: '当前服务商',
          icon: Icons.cloud_outlined,
          onTap: onPickKind,
          trailing: const AppText('更换', role: AppTextRole.caption),
        ),
        const SizedBox(height: AppTheme.spaceGroup),
        AppTextField(
          label: '服务地址',
          controller: baseUrl,
          hint: defaultBaseUrl,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          onChanged: onBaseChanged,
          onEditingComplete: onBaseComplete,
        ),
        const SizedBox(height: AppTheme.spaceGroup),
        if (needsApiKey) ...[
          AppTextField(
            label: '密钥',
            controller: apiKey,
            obscureText: true,
            hint: 'sk-…',
            textInputAction: TextInputAction.done,
            onChanged: onKeyChanged,
            onEditingComplete: onKeyComplete,
            onSubmitted: (_) => onKeyComplete(),
          ),
          const SizedBox(height: AppTheme.spaceGroup),
        ],
        AppSelectField(
          label: '模型',
          value: model,
          hint: modelHint,
          onTap: onPickModel,
          trailing: AppButton(
            label: probing ? '查找中' : '查找模型',
            variant: AppButtonVariant.secondary,
            onPressed: onProbe,
          ),
        ),
        if (probeStatus != null) ...[
          const SizedBox(height: AppTheme.spaceXs),
          AppText(probeStatus!, role: AppTextRole.caption),
        ],
      ],
    );
  }
}

String? _modelHint(String model, bool probing, List<String> models) {
  if (model.trim().isNotEmpty) return null;
  if (probing) return '正在查找…';
  if (models.isEmpty) return '点这里选择，或先查找可用模型';
  return '已找到 ${models.length} 个';
}

Future<String?> _showModelSheet(
  BuildContext context, {
  required List<String> models,
  required String current,
}) {
  return showAppSheet<String>(
    context: context,
    heightFactor: 0.55,
    builder: (context) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          AppTheme.spaceXs,
          AppTheme.pagePadding,
          AppTheme.spaceMd,
        ),
        children: [
          const AppSectionHeader('选择模型'),
          const SizedBox(height: AppTheme.spaceGroup),
          for (final id in models) ...[
            AppListTile(
              title: id,
              icon: Icons.smart_toy_outlined,
              onTap: () => Navigator.of(context).pop(id),
              trailing: id == current
                  ? const AppText('当前', role: AppTextRole.caption)
                  : null,
            ),
            const SizedBox(height: AppTheme.spaceGroup),
          ],
        ],
      );
    },
  );
}
