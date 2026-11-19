import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/expand_plot_element_description_action.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// Global plot-element library (CRUD). Managed under 玩法; stories only pick.
class PlotElementsLibraryPage extends StatefulWidget {
  const PlotElementsLibraryPage({super.key});

  @override
  State<PlotElementsLibraryPage> createState() =>
      _PlotElementsLibraryPageState();
}

class _PlotElementsLibraryPageState extends State<PlotElementsLibraryPage> {
  SettingsController get _settings => AppScope.settingsOf(context);

  String _preview(PlotElement element) {
    final text = element.clippedDescription;
    if (text.isEmpty) return '还没写描述';
    return text.length > 48 ? '${text.substring(0, 48)}…' : text;
  }

  Future<void> _edit({PlotElement? existing}) async {
    final catalog = _settings.plotElements;
    final result = await showAppSheet<_PlotElementSheetResult>(
      context: context,
      size: AppSheetSize.half,
      builder: (sheetContext) => _PlotElementEditSheet(
        existing: existing,
        isBuiltIn: existing != null && catalog.isBuiltInId(existing.id),
        isModified: existing != null && catalog.isModifiedBuiltIn(existing.id),
      ),
    );
    if (result == null || !mounted) return;

    switch (result) {
      case _PlotElementSheetSave(:final keyword, :final description):
        if (existing == null) {
          await _settings.addCustomPlotElement(
            keyword: keyword,
            description: description,
          );
        } else if (catalog.isBuiltInId(existing.id)) {
          await _settings.updateBuiltInPlotElement(
            id: existing.id,
            keyword: keyword,
            description: description,
          );
        } else {
          await _settings.upsertPlotElement(
            existing.copyWith(keyword: keyword, description: description),
          );
        }
      case _PlotElementSheetDelete():
        if (existing == null) return;
        final confirmed = await _confirm(
          title: '删除这个剧情元素？',
          detail: catalog.isBuiltInId(existing.id)
              ? '可从菜单「全部恢复默认」再加回来'
              : '删掉后无法恢复',
          confirmLabel: '删除',
          danger: true,
        );
        if (!confirmed || !mounted) return;
        await _settings.deletePlotElement(existing.id);
      case _PlotElementSheetRestore():
        if (existing == null) return;
        await _settings.restoreBuiltInPlotElement(existing.id);
    }
  }

  Future<void> _restoreAll() async {
    final confirmed = await _confirm(
      title: '全部恢复默认？',
      detail: '出厂条目会恢复原文并补回已删的；你自己加的保留',
      confirmLabel: '全部恢复',
    );
    if (!confirmed || !mounted) return;
    await _settings.restoreAllBuiltInPlotElements();
  }

  Future<bool> _confirm({
    required String title,
    required String detail,
    required String confirmLabel,
    bool danger = false,
  }) async {
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
            AppText(title, role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceXs),
            AppText(detail, role: AppTextRole.caption),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    variant: danger
                        ? AppButtonVariant.danger
                        : AppButtonVariant.primary,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  Future<void> _openMore() async {
    final action = await showAppSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spaceSm),
          AppListTile(
            title: '全部恢复默认',
            subtitle: '出厂条目恢复原文并补回已删的',
            icon: Icons.restart_alt_outlined,
            showDivider: false,
            onTap: () => Navigator.of(ctx).pop('restore_all'),
          ),
          const SizedBox(height: AppTheme.pagePadding),
        ],
      ),
    );
    if (action == 'restore_all' && mounted) {
      await _restoreAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final catalog = _settings.plotElements;
        final rows = catalog.effectiveList;
        return AppPage(
          title: '剧情元素',
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            AppIconButton(
              icon: Icons.more_horiz,
              tooltip: '更多',
              onPressed: _openMore,
            ),
            AppCircleButton(
              icon: Icons.add,
              tooltip: '加一条',
              onPressed: () => _edit(),
            ),
          ],
          body: AppPageBody.list(
            children: [
              const AppSectionHeader(
                '全局库',
                subtitle: '供 AI 织进支线的由头，故事里只勾选',
                gutter: true,
              ),
              if (rows.isEmpty)
                AppPageGutter(
                  child: AppEmptyState(
                    message: '库是空的',
                    detail: '加一条，或全部恢复默认',
                    action: AppButton(
                      label: '加一条',
                      onPressed: () => _edit(),
                      variant: AppButtonVariant.secondary,
                    ),
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      AppListTile(
                        title: rows[i].keyword.isEmpty
                            ? '未命名'
                            : rows[i].keyword,
                        subtitle: catalog.isBuiltInId(rows[i].id)
                            ? (catalog.isModifiedBuiltIn(rows[i].id)
                                ? '默认 · 已改 · ${_preview(rows[i])}'
                                : '默认 · ${_preview(rows[i])}')
                            : _preview(rows[i]),
                        icon: Icons.auto_awesome_outlined,
                        trailing: const AppForwardIcon(),
                        showDivider: false,
                        onTap: () => _edit(existing: rows[i]),
                      ),
                      if (i < rows.length - 1) const AppListHairline(),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

sealed class _PlotElementSheetResult {
  const _PlotElementSheetResult();
}

final class _PlotElementSheetSave extends _PlotElementSheetResult {
  const _PlotElementSheetSave({
    required this.keyword,
    required this.description,
  });

  final String keyword;
  final String description;
}

final class _PlotElementSheetDelete extends _PlotElementSheetResult {
  const _PlotElementSheetDelete();
}

final class _PlotElementSheetRestore extends _PlotElementSheetResult {
  const _PlotElementSheetRestore();
}

class _PlotElementEditSheet extends StatefulWidget {
  const _PlotElementEditSheet({
    required this.existing,
    required this.isBuiltIn,
    required this.isModified,
  });

  final PlotElement? existing;
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
  var _busy = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _baselineKeyword = widget.existing?.keyword ?? '';
    _baselineDescription = widget.existing?.description ?? '';
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
      _description.text.trim() != _baselineDescription.trim();

  void _save() {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty) return;
    Navigator.of(context).pop(
      _PlotElementSheetSave(
        keyword: keyword,
        description: _description.text,
      ),
    );
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _aiError = null;
    });
    try {
      final settings = AppScope.settingsOf(context);
      final text = await ExpandPlotElementDescriptionAction(
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
        _aiError = '没写出来，请稍后再试';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return AppSheetEditForm(
      title: existing == null ? '新剧情元素' : '编辑剧情元素',
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
            label: '关键词',
            controller: _keyword,
            hint: '救助流浪猫、雨夜共伞…',
            autofocus: existing == null,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: '描述',
            controller: _description,
            minLines: 4,
            maxLines: 8,
            hint: '说明怎么用，再写一句示例剧情',
          ),
          const SizedBox(height: AppTheme.spaceSm),
          AppText(
            '最多 $kPlotElementDescriptionMaxChars 字',
            role: AppTextRole.caption,
          ),
          if (_aiError != null) ...[
            const SizedBox(height: AppTheme.spaceXs),
            AppText(_aiError!, role: AppTextRole.caption),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          AppButton(
            label: _busy ? '正在写…' : '生成描述',
            variant: AppButtonVariant.secondary,
            onPressed: _busy ? null : _generate,
          ),
          if (existing != null) ...[
            const SizedBox(height: AppTheme.spaceMd),
            if (widget.isBuiltIn && widget.isModified)
              AppButton(
                label: '恢复默认',
                variant: AppButtonVariant.secondary,
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(
                          const _PlotElementSheetRestore(),
                        ),
              ),
            if (widget.isBuiltIn && widget.isModified)
              const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '删除',
              variant: AppButtonVariant.danger,
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).pop(
                        const _PlotElementSheetDelete(),
                      ),
            ),
          ],
        ],
      ),
    );
  }
}
