import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/ai/ai_model_catalog.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

class AiSettingsPanel extends StatefulWidget {
  const AiSettingsPanel({super.key});

  @override
  State<AiSettingsPanel> createState() => _AiSettingsPanelState();
}

class _AiSettingsPanelState extends State<AiSettingsPanel> {
  String? _status;

  Future<void> _persist(AiSettings next, {String? status}) async {
    await AppScope.settingsOf(context).updateAi(next);
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<AiProviderKind?> _pickKind(AiProviderKind current) {
    return showModalBottomSheet<AiProviderKind>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceSm,
              AppTheme.pagePadding,
              AppTheme.spaceLg,
            ),
            children: [
              const AppSectionHeader('选择供应商'),
              const SizedBox(height: AppTheme.spaceXs),
              const AppText(
                '选预设或「自定义」；Base URL 仍可手改。',
                role: AppTextRole.caption,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              for (final kind in AiProviderKind.values) ...[
                AppListTile(
                  title: kind.label,
                  subtitle: kind.defaultBaseUrl,
                  onTap: () => Navigator.of(context).pop(kind),
                  trailing: kind == current
                      ? const AppText('当前', role: AppTextRole.caption)
                      : null,
                ),
                const SizedBox(height: AppTheme.spaceSm),
              ],
            ],
          ),
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
            _ChannelEditor(
              title: '文本 AI',
              caption: '选择供应商后填写 Base URL 与密钥；输入密钥后会自动探测可用模型。',
              endpoint: ai.text,
              forImage: false,
              catalog: catalog,
              onPickKind: () async {
                final kind = await _pickKind(ai.text.kind);
                if (kind == null || !mounted) return;
                await _persist(ai.switchTextKind(kind));
              },
              onSave: (endpoint) async {
                await _persist(ai.withText(endpoint), status: '文本 AI 已保存');
              },
            ),
            const SizedBox(height: AppTheme.spaceLg),
            _ChannelEditor(
              title: '生图 AI',
              caption: '可与文本选用不同供应商；同样支持密钥后自动探测模型。',
              endpoint: ai.image,
              forImage: true,
              catalog: catalog,
              onPickKind: () async {
                final kind = await _pickKind(ai.image.kind);
                if (kind == null || !mounted) return;
                await _persist(ai.switchImageKind(kind));
              },
              onSave: (endpoint) async {
                await _persist(ai.withImage(endpoint), status: '生图 AI 已保存');
              },
            ),
            if (_status != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              AppText(_status!, role: AppTextRole.caption),
            ],
          ],
        );
      },
    );
  }
}

class _ChannelEditor extends StatefulWidget {
  const _ChannelEditor({
    required this.title,
    required this.caption,
    required this.endpoint,
    required this.forImage,
    required this.catalog,
    required this.onPickKind,
    required this.onSave,
  });

  final String title;
  final String caption;
  final AiEndpointConfig endpoint;
  final bool forImage;
  final AiModelCatalog catalog;
  final VoidCallback onPickKind;
  final ValueChanged<AiEndpointConfig> onSave;

  @override
  State<_ChannelEditor> createState() => _ChannelEditorState();
}

class _ChannelEditorState extends State<_ChannelEditor> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  AiProviderKind? _boundKind;

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
    _model = TextEditingController(text: widget.endpoint.model);
    _boundKind = widget.endpoint.kind;
    _scheduleAutoProbe(immediate: true);
  }

  @override
  void didUpdateWidget(covariant _ChannelEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.endpoint.kind != _boundKind) {
      _boundKind = widget.endpoint.kind;
      _baseUrl.text = widget.endpoint.baseUrl;
      _apiKey.text = widget.endpoint.apiKey;
      _model.text = widget.endpoint.model;
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
    _model.dispose();
    super.dispose();
  }

  AiEndpointConfig get _draft => widget.endpoint.copyWith(
        baseUrl: _baseUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
        model: _model.text.trim(),
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
    if (d.kind.needsApiKey && d.apiKey.isEmpty) return false;
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
        _probeStatus = widget.endpoint.kind.needsApiKey
            ? '填写 Base URL 与 API Key 后自动探测'
            : '填写 Base URL 后自动探测';
      });
      return;
    }
    final signature = _probeSignature;
    if (!force && signature == _lastProbedSignature && _models.isNotEmpty) {
      return;
    }
    setState(() {
      _probing = true;
      _probeStatus = '正在探测可用模型…';
    });
    try {
      final models = await widget.catalog.listModels(_draft);
      if (!mounted) return;
      setState(() {
        _models = models;
        _probing = false;
        _lastProbedSignature = signature;
        _probeStatus = '已探测到 ${models.length} 个模型';
        if (_model.text.trim().isEmpty && models.isNotEmpty) {
          _model.text = models.first;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _probing = false;
        _probeStatus = error is AiModelCatalogException
            ? error.message
            : '探测失败：$error';
      });
    }
  }

  Future<void> _pickModel() async {
    if (_models.isEmpty && !_probing) {
      await _probeModels(force: true);
    }
    if (!mounted || _models.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.spaceSm,
                AppTheme.pagePadding,
                AppTheme.spaceLg,
              ),
              children: [
                const AppSectionHeader('选择模型'),
                const SizedBox(height: AppTheme.spaceMd),
                for (final id in _models) ...[
                  AppListTile(
                    title: id,
                    onTap: () => Navigator.of(context).pop(id),
                    trailing: id == _model.text.trim()
                        ? const AppText('当前', role: AppTextRole.caption)
                        : null,
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() => _model.text = selected);
  }

  @override
  Widget build(BuildContext context) {
    final endpoint = widget.endpoint;
    final modelHint = widget.forImage
        ? (endpoint.kind.defaultImageModel().isEmpty
            ? 'dall-e-3'
            : endpoint.kind.defaultImageModel())
        : (endpoint.kind.defaultTextModel().isEmpty
            ? 'gpt-4o-mini'
            : endpoint.kind.defaultTextModel());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(widget.title),
        AppText(widget.caption, role: AppTextRole.caption),
        const SizedBox(height: AppTheme.spaceMd),
        AppListTile(
          title: '供应商',
          subtitle: endpoint.kind.label,
          onTap: widget.onPickKind,
          trailing: const AppText('更换', role: AppTextRole.caption),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        AppTextField(
          label: 'Base URL',
          controller: _baseUrl,
          hint: endpoint.kind.defaultBaseUrl,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _scheduleAutoProbe(),
          onEditingComplete: () => _scheduleAutoProbe(immediate: true),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        if (endpoint.kind.needsApiKey) ...[
          AppTextField(
            label: 'API Key',
            controller: _apiKey,
            obscureText: true,
            hint: 'sk-…',
            textInputAction: TextInputAction.next,
            onChanged: (_) => _scheduleAutoProbe(),
            onEditingComplete: () => _scheduleAutoProbe(immediate: true),
            onSubmitted: (_) => _scheduleAutoProbe(immediate: true),
          ),
          const SizedBox(height: AppTheme.spaceSm),
        ],
        AppListTile(
          title: '可用模型',
          subtitle: _probing
              ? '探测中…'
              : (_models.isEmpty
                  ? '输入密钥后自动探测，或点此刷新'
                  : '已探测 ${_models.length} 个，点此选择'),
          onTap: _probing ? null : _pickModel,
          trailing: AppText(
            _probing ? '…' : '选择',
            role: AppTextRole.caption,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        AppTextField(
          label: '模型',
          controller: _model,
          hint: modelHint,
        ),
        if (_probeStatus != null) ...[
          const SizedBox(height: AppTheme.spaceXs),
          AppText(_probeStatus!, role: AppTextRole.caption),
        ],
        const SizedBox(height: AppTheme.spaceMd),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: '探测模型',
                variant: AppButtonVariant.secondary,
                expanded: true,
                onPressed: _probing ? null : () => _probeModels(force: true),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: AppButton(
                label: '保存',
                expanded: true,
                onPressed: () => widget.onSave(_draft),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
