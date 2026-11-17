import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

class PersonaEditorPage extends StatefulWidget {
  const PersonaEditorPage({super.key, this.persona});

  final UserPersona? persona;

  @override
  State<PersonaEditorPage> createState() => _PersonaEditorPageState();
}

class _PersonaEditorPageState extends State<PersonaEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _system;
  late final TextEditingController _postHistory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.persona;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _system = TextEditingController(text: p?.systemPromptOverride ?? '');
    _postHistory = TextEditingController(text: p?.postHistoryInstructions ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _system.dispose();
    _postHistory.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final controller = AppScope.settingsOf(context);
    final existing = widget.persona;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (existing == null) {
        final created = await controller.createPersona(name: name);
        await controller.savePersona(
          created.copyWith(
            description: _description.text.trim(),
            systemPromptOverride: _system.text.trim().isEmpty
                ? null
                : _system.text.trim(),
            postHistoryInstructions: _postHistory.text.trim().isEmpty
                ? null
                : _postHistory.text.trim(),
            clearSystemPromptOverride: _system.text.trim().isEmpty,
            clearPostHistoryInstructions: _postHistory.text.trim().isEmpty,
          ),
        );
      } else {
        await controller.savePersona(
          existing.copyWith(
            name: name,
            description: _description.text.trim(),
            systemPromptOverride: _system.text.trim().isEmpty
                ? null
                : _system.text.trim(),
            postHistoryInstructions: _postHistory.text.trim().isEmpty
                ? null
                : _postHistory.text.trim(),
            clearSystemPromptOverride: _system.text.trim().isEmpty,
            clearPostHistoryInstructions: _postHistory.text.trim().isEmpty,
          ),
        );
      }
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.persona != null;
    return AppPage(
      title: editing ? '编辑身份' : '新建身份',
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody(
        children: [
          AppTextField(
            label: '名字',
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: '身份说明',
            controller: _description,
            minLines: 3,
            maxLines: 8,
            hint: '你在故事里是谁、怎么说话',
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: '专用系统说明',
            controller: _system,
            minLines: 2,
            maxLines: 6,
            hint: '可选，沿用酒馆写法',
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: '历史后说明',
            controller: _postHistory,
            minLines: 2,
            maxLines: 6,
            hint: '可选，对应 jailbreak 段',
          ),
          const SizedBox(height: AppTheme.spaceLg),
          AppButton(
            label: _saving ? '保存中…' : '保存',
            expanded: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}