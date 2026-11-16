import 'package:anoworld/app/app_scope.dart';
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ai = controller.ai;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChannelEditor(
              title: '文本 AI',
              caption: '选择一个供应商（或自定义），填写 Base URL、密钥与模型。',
              endpoint: ai.text,
              forImage: false,
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
              caption: '可与文本选用不同供应商；同样支持自定义 Base URL。',
              endpoint: ai.image,
              forImage: true,
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
    required this.onPickKind,
    required this.onSave,
  });

  final String title;
  final String caption;
  final AiEndpointConfig endpoint;
  final bool forImage;
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

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: widget.endpoint.baseUrl);
    _apiKey = TextEditingController(text: widget.endpoint.apiKey);
    _model = TextEditingController(text: widget.endpoint.model);
    _boundKind = widget.endpoint.kind;
  }

  @override
  void didUpdateWidget(covariant _ChannelEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.endpoint.kind != _boundKind) {
      _boundKind = widget.endpoint.kind;
      _baseUrl.text = widget.endpoint.baseUrl;
      _apiKey.text = widget.endpoint.apiKey;
      _model.text = widget.endpoint.model;
    }
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
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
        ),
        const SizedBox(height: AppTheme.spaceSm),
        if (endpoint.kind.needsApiKey) ...[
          AppTextField(
            label: 'API Key',
            controller: _apiKey,
            obscureText: true,
            hint: 'sk-…',
          ),
          const SizedBox(height: AppTheme.spaceSm),
        ],
        AppTextField(
          label: '模型',
          controller: _model,
          hint: modelHint,
        ),
        const SizedBox(height: AppTheme.spaceMd),
        AppButton(
          label: '保存',
          expanded: true,
          onPressed: () {
            widget.onSave(
              endpoint.copyWith(
                baseUrl: _baseUrl.text.trim(),
                apiKey: _apiKey.text.trim(),
                model: _model.text.trim(),
              ),
            );
          },
        ),
      ],
    );
  }
}
