import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
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
      size: AppSheetSize.half,
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.spaceXs,
                AppTheme.pagePadding,
                0,
              ),
              child: AppSectionHeader(
                '选择供应商',
                subtitle: '写故事与生图请分开选择',
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
                        ? const AppText('当前', role: AppTextRole.caption)
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
    _scheduleAutoProbe(immediate: true);
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
      final models = await widget.catalog
          .listModels(AiEndpointConfig.fromText(_endpoint));
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
        widget.onChanged(_endpoint.copyWith(model: models.first));
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
    widget.onChanged(_endpoint.copyWith(model: selected));
  }

  @override
  Widget build(BuildContext context) {
    return _ChannelScaffold(
      title: '文本 AI',
      caption: '写对白与剧情',
      providerLabel: widget.endpoint.kind.label,
      onPickKind: widget.onPickKind,
      baseUrl: widget.endpoint.baseUrl,
      apiKey: widget.endpoint.apiKey,
      defaultBaseUrl: widget.endpoint.kind.defaultBaseUrl,
      needsApiKey: widget.endpoint.needsApiKey,
      model: widget.endpoint.model,
      modelHint: _modelHint(widget.endpoint.model, _probing, _models),
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
    _scheduleAutoProbe(immediate: true);
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
        _probeStatus = '找到 ${models.length} 个可用模型';
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
    widget.onChanged(_endpoint.copyWith(model: selected));
  }

  @override
  Widget build(BuildContext context) {
    return _ChannelScaffold(
      title: '生图 AI',
      caption: '生成插画，与文本分开',
      providerLabel: widget.endpoint.kind.label,
      onPickKind: widget.onPickKind,
      baseUrl: widget.endpoint.baseUrl,
      apiKey: widget.endpoint.apiKey,
      defaultBaseUrl: widget.endpoint.kind.defaultBaseUrl,
      needsApiKey: widget.endpoint.needsApiKey,
      model: widget.endpoint.model,
      modelHint: _modelHint(widget.endpoint.model, _probing, _models),
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

  @override
  Widget build(BuildContext context) {
    final modelTrailing = model.trim().isEmpty
        ? (modelHint ?? '未选择')
        : model.trim();
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
          subtitle: '当前服务商',
          icon: Icons.cloud_outlined,
          onTap: onPickKind,
          trailing: const AppText('更换', role: AppTextRole.caption),
        ),
        AppTextEditTile(
          title: '服务地址',
          subtitle: '接口根地址',
          icon: Icons.link_outlined,
          value: baseUrl,
          hint: defaultBaseUrl,
          emptyLabel: defaultBaseUrl.isEmpty ? '未填写' : defaultBaseUrl,
          keyboardType: TextInputType.url,
          onSubmitted: onBaseSubmitted,
        ),
        if (needsApiKey)
          AppTextEditTile(
            title: '密钥',
            subtitle: '访问服务用',
            icon: Icons.key_outlined,
            value: apiKey,
            hint: 'sk-…',
            obscureText: true,
            onSubmitted: onKeySubmitted,
          ),
        AppListTile(
          title: '模型',
          subtitle: probing ? '正在查找…' : '点这里选择',
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
        AppListTile(
          title: probing ? '正在查找模型' : '查找模型',
          subtitle: probeStatus ?? '重新拉取可用列表',
          icon: Icons.refresh_outlined,
          onTap: onProbe,
          showDivider: false,
        ),
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
    size: AppSheetSize.half,
    builder: (context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceXs,
              AppTheme.pagePadding,
              AppTheme.spaceXs,
            ),
            child: AppSectionHeader('选择模型'),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppTheme.spaceGroup,
                0,
                AppTheme.spaceMd,
              ),
              itemCount: models.length,
              separatorBuilder: (_, _) => const SizedBox.shrink(),
              itemBuilder: (context, index) {
                final id = models[index];
                return AppListTile(
                  title: id,
                  icon: Icons.smart_toy_outlined,
                  onTap: () => Navigator.of(context).pop(id),
                  trailing: id == current
                      ? const AppText('当前', role: AppTextRole.caption)
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
