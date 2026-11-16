import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
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
  final _textUrl = TextEditingController();
  final _textKey = TextEditingController();
  final _textModel = TextEditingController();
  final _imageUrl = TextEditingController();
  final _imageKey = TextEditingController();
  final _imageModel = TextEditingController();
  bool _seeded = false;
  String? _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final ai = AppScope.settingsOf(context).ai;
    _textUrl.text = ai.text.baseUrl;
    _textKey.text = ai.text.apiKey;
    _textModel.text = ai.text.model;
    _imageUrl.text = ai.image.baseUrl;
    _imageKey.text = ai.image.apiKey;
    _imageModel.text = ai.image.model;
  }

  @override
  void dispose() {
    _textUrl.dispose();
    _textKey.dispose();
    _textModel.dispose();
    _imageUrl.dispose();
    _imageKey.dispose();
    _imageModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = AiSettings(
      text: AiEndpointConfig(
        baseUrl: _textUrl.text.trim(),
        apiKey: _textKey.text.trim(),
        model: _textModel.text.trim(),
      ),
      image: AiEndpointConfig(
        baseUrl: _imageUrl.text.trim(),
        apiKey: _imageKey.text.trim(),
        model: _imageModel.text.trim(),
      ),
    );
    await AppScope.settingsOf(context).updateAi(next);
    if (!mounted) return;
    setState(() => _status = '已保存');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader('文本 AI'),
        const AppText(
          'OpenAI 兼容接口：填写 Base URL、密钥与模型。',
          role: AppTextRole.caption,
        ),
        const SizedBox(height: AppTheme.spaceMd),
        AppTextField(
          label: 'Base URL',
          controller: _textUrl,
          hint: 'https://api.example.com/v1',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppTheme.spaceSm),
        AppTextField(
          label: 'API Key',
          controller: _textKey,
          obscureText: true,
          hint: 'sk-…',
        ),
        const SizedBox(height: AppTheme.spaceSm),
        AppTextField(
          label: '模型',
          controller: _textModel,
          hint: 'gpt-4o-mini',
        ),
        const SizedBox(height: AppTheme.spaceLg),
        const AppSectionHeader('生图 AI'),
        const AppText(
          '同样按 OpenAI 兼容字段配置；可与文本使用不同服务。',
          role: AppTextRole.caption,
        ),
        const SizedBox(height: AppTheme.spaceMd),
        AppTextField(
          label: 'Base URL',
          controller: _imageUrl,
          hint: 'https://api.example.com/v1',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppTheme.spaceSm),
        AppTextField(
          label: 'API Key',
          controller: _imageKey,
          obscureText: true,
        ),
        const SizedBox(height: AppTheme.spaceSm),
        AppTextField(
          label: '模型',
          controller: _imageModel,
          hint: 'dall-e-3',
        ),
        const SizedBox(height: AppTheme.spaceLg),
        AppButton(label: '保存', onPressed: _save, expanded: true),
        if (_status != null) ...[
          const SizedBox(height: AppTheme.spaceSm),
          AppText(_status!, role: AppTextRole.caption),
        ],
      ],
    );
  }
}
