import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
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
  bool _deleting = false;

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
    if (_saving || _deleting) return;
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
    } catch (error, stack) {
      AppLog.instance.error(
        '保存身份失败',
        tag: 'persona.edit',
        error: error,
        stackTrace: stack,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.persona;
    if (existing == null || existing.isDefault || _saving || _deleting) return;
    final strings = context.strings;
    final confirmed = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          AppTheme.spaceSm,
          AppTheme.pagePadding,
          AppTheme.pagePadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(
              strings.deletePersonaTitle(existing.name),
              role: AppTextRole.subtitle,
            ),
            const SizedBox(height: AppTheme.spaceXs),
            AppText(
              strings.deletePersonaHint,
              role: AppTextRole.caption,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: strings.cancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: AppButton(
                    label: strings.delete,
                    variant: AppButtonVariant.danger,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await AppScope.settingsOf(context).deletePersona(existing.id);
      if (mounted) Navigator.of(context).maybePop();
    } catch (error, stack) {
      AppLog.instance.error(
        '删除身份失败',
        tag: 'persona.edit',
        error: error,
        stackTrace: stack,
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final editing = widget.persona != null;
    final canDelete = editing && !(widget.persona?.isDefault ?? true);
    final busy = _saving || _deleting;
    return AppPage(
      title: editing ? strings.editPersona : strings.addPersona,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody(
        children: [
          AppTextField(
            label: strings.personaNameLabel,
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: strings.personaAboutLabel,
            controller: _description,
            minLines: 3,
            maxLines: 8,
            hint: strings.personaAboutHint,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: strings.personaSystemLabel,
            controller: _system,
            minLines: 2,
            maxLines: 6,
            hint: strings.personaSystemHint,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: strings.personaPostLabel,
            controller: _postHistory,
            minLines: 2,
            maxLines: 6,
            hint: strings.personaPostHint,
          ),
          const SizedBox(height: AppTheme.spaceLg),
          AppButton(
            label: _saving ? strings.savingDots : strings.save,
            expanded: true,
            onPressed: busy ? null : _save,
          ),
          if (canDelete) ...[
            const SizedBox(height: AppTheme.spaceMd),
            AppButton(
              label: _deleting ? strings.deletingDots : strings.delete,
              variant: AppButtonVariant.danger,
              expanded: true,
              onPressed: busy ? null : _delete,
            ),
          ],
        ],
      ),
    );
  }
}
