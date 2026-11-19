import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/expand_plot_element_description_action.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_confirm_sheet.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_select_field.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:anoworld/play/plot_element_category_ui.dart';
import 'package:flutter/material.dart';

/// Outcome of [showPlotElementEditor].
sealed class PlotElementEditResult {
  const PlotElementEditResult();
}

final class PlotElementEditSave extends PlotElementEditResult {
  const PlotElementEditSave({
    required this.keyword,
    required this.description,
    required this.categoryId,
  });

  final String keyword;
  final String description;
  final String categoryId;
}

final class PlotElementEditDelete extends PlotElementEditResult {
  const PlotElementEditDelete();
}

final class PlotElementEditRestore extends PlotElementEditResult {
  const PlotElementEditRestore();
}

/// Opens the half sheet that edits one library row; null when dismissed.
Future<PlotElementEditResult?> showPlotElementEditor(
  BuildContext context, {
  PlotElement? existing,
  String initialCategoryId = '',
}) {
  final catalog = AppScope.settingsOf(context).plotElements;
  return showAppSheet<PlotElementEditResult>(
    context: context,
    size: AppSheetSize.half,
    builder: (sheetContext) => _PlotElementEditSheet(
      existing: existing,
      initialCategoryId: existing?.categoryId ?? initialCategoryId,
      isBuiltIn: existing != null && catalog.isBuiltInId(existing.id),
      isModified: existing != null && catalog.isModifiedBuiltIn(existing.id),
    ),
  );
}

/// Applies an editor result to the global library (delete asks first).
Future<void> commitPlotElementEdit(
  BuildContext context, {
  required SettingsController settings,
  PlotElement? existing,
  required PlotElementEditResult result,
}) async {
  final catalog = settings.plotElements;
  switch (result) {
    case PlotElementEditSave(
      :final keyword,
      :final description,
      :final categoryId,
    ):
      if (existing == null) {
        await settings.addCustomPlotElement(
          keyword: keyword,
          description: description,
          categoryId: categoryId,
        );
      } else if (catalog.isBuiltInId(existing.id)) {
        await settings.updateBuiltInPlotElement(
          id: existing.id,
          keyword: keyword,
          description: description,
          categoryId: categoryId,
        );
      } else {
        await settings.upsertPlotElement(
          existing.copyWith(
            keyword: keyword,
            description: description,
            categoryId: categoryId,
          ),
        );
      }
    case PlotElementEditDelete():
      if (existing == null) return;
      final strings = context.strings;
      final confirmed = await showAppConfirmSheet(
        context,
        title: strings.deleteElementTitle,
        detail: catalog.isBuiltInId(existing.id)
            ? strings.deleteElementBuiltInDetail
            : strings.deleteElementCustomDetail,
        confirmLabel: strings.delete,
        danger: true,
      );
      if (!confirmed) return;
      await settings.deletePlotElement(existing.id);
    case PlotElementEditRestore():
      if (existing == null) return;
      await settings.restoreBuiltInPlotElement(existing.id);
  }
}

typedef _CategoryChoice = ({String? categoryId, bool create});

class _PlotElementEditSheet extends StatefulWidget {
  const _PlotElementEditSheet({
    required this.existing,
    required this.initialCategoryId,
    required this.isBuiltIn,
    required this.isModified,
  });

  final PlotElement? existing;
  final String initialCategoryId;
  final bool isBuiltIn;
  final bool isModified;

  @override
  State<_PlotElementEditSheet> createState() => _PlotElementEditSheetState();
}

class _PlotElementEditSheetState extends State<_PlotElementEditSheet> {
  late final TextEditingController _keyword;
  late final TextEditingController _description;
  late final String _baselineKeyword;
  late final String _baselineDescription;
  late final String _baselineCategoryId;
  late String _categoryId;
  var _busy = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _baselineKeyword = widget.existing?.keyword ?? '';
    _baselineDescription = widget.existing?.description ?? '';
    _baselineCategoryId = widget.initialCategoryId;
    _categoryId = widget.initialCategoryId;
    _keyword = TextEditingController(text: _baselineKeyword);
    _description = TextEditingController(text: _baselineDescription);
    _keyword.addListener(_markDirty);
    _description.addListener(_markDirty);
  }

  void _markDirty() => setState(() {});

  @override
  void dispose() {
    _keyword.removeListener(_markDirty);
    _description.removeListener(_markDirty);
    _keyword.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _keyword.text.trim() != _baselineKeyword.trim() ||
      _description.text.trim() != _baselineDescription.trim() ||
      _categoryId != _baselineCategoryId;

  void _save() {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty) return;
    Navigator.of(context).pop(
      PlotElementEditSave(
        keyword: keyword,
        description: _description.text,
        categoryId: _categoryId,
      ),
    );
  }

  Future<void> _pickCategory() async {
    final settings = AppScope.settingsOf(context);
    final strings = context.strings;
    final choice = await showAppSheet<_CategoryChoice>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceXs,
              AppTheme.pagePadding,
              0,
            ),
            child: AppSectionHeader(strings.categoryLabel),
          ),
          AppListTile(
            title: strings.uncategorized,
            selected: _categoryId.isEmpty,
            onTap: () => Navigator.of(ctx).pop((categoryId: '', create: false)),
          ),
          for (final category in settings.plotElements.categories)
            AppListTile(
              title: category.name,
              selected: category.id == _categoryId,
              onTap: () =>
                  Navigator.of(ctx)
                      .pop((categoryId: category.id, create: false)),
            ),
          AppListTile(
            title: strings.newCategory,
            icon: Icons.create_new_folder_outlined,
            showDivider: false,
            onTap: () =>
                Navigator.of(ctx).pop((categoryId: null, create: true)),
          ),
          const SizedBox(height: AppTheme.pagePadding),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.create) {
      final name = await askPlotElementCategoryName(
        context,
        title: strings.newCategoryTitle,
      );
      if (name == null || !mounted) return;
      final category = await settings.addPlotElementCategory(name);
      if (!mounted) return;
      setState(() => _categoryId = category.id);
      return;
    }
    final picked = choice.categoryId;
    if (picked == null) return;
    setState(() => _categoryId = picked);
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _aiError = null;
    });
    try {
      final settings = AppScope.settingsOf(context);
      final text =
          await ExpandPlotElementDescriptionAction(
            textClient: AppScope.textClientOf(context),
          ).expand(
            endpoint: settings.ai.text,
            generation: settings.ai.generation,
            keyword: _keyword.text,
            existingDescription: _description.text,
          );
      if (!mounted) return;
      setState(() {
        _description.text = text;
        _busy = false;
      });
    } on AiTextException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiError = error.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiError = context.strings.generateFailed;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final strings = context.strings;
    final catalog = AppScope.settingsOf(context).plotElements;
    return AppSheetEditForm(
      title: existing == null
          ? strings.newElementTitle
          : strings.editElementTitle,
      isDirty: _isDirty,
      onSave: _save,
      body: AppSheetScrollBody(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          0,
          AppTheme.pagePadding,
          AppTheme.spaceMd,
        ),
        children: [
          AppTextField(
            label: strings.keywordLabel,
            controller: _keyword,
            hint: strings.keywordHint,
            autofocus: existing == null,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppSelectField(
            label: strings.categoryLabel,
            value: _categoryId.isEmpty
                ? ''
                : catalog.categoryNameOf(_categoryId),
            hint: strings.uncategorized,
            onTap: _pickCategory,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: strings.descriptionLabel,
            controller: _description,
            minLines: 4,
            maxLines: 8,
            hint: strings.descriptionHint,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          AppText(
            strings.maxChars(kPlotElementDescriptionMaxChars),
            role: AppTextRole.caption,
          ),
          if (_aiError != null) ...[
            const SizedBox(height: AppTheme.spaceXs),
            AppText(_aiError!, role: AppTextRole.caption),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          AppButton(
            label: _busy
                ? strings.generating
                : strings.generateDescription,
            variant: AppButtonVariant.secondary,
            onPressed: _busy ? null : _generate,
          ),
          if (existing != null) ...[
            const SizedBox(height: AppTheme.spaceMd),
            if (widget.isBuiltIn && widget.isModified)
              AppButton(
                label: strings.restoreDefault,
                variant: AppButtonVariant.secondary,
                onPressed: _busy
                    ? null
                    : () =>
                          Navigator.of(context)
                              .pop(const PlotElementEditRestore()),
              ),
            if (widget.isBuiltIn && widget.isModified)
              const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: strings.delete,
              variant: AppButtonVariant.danger,
              onPressed: _busy
                  ? null
                  : () =>
                        Navigator.of(context)
                            .pop(const PlotElementEditDelete()),
            ),
          ],
        ],
      ),
    );
  }
}
