import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/logging/app_log_entry.dart';
import 'package:anoworld/foundation/logging/app_log_level.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Lazy list over the in-memory log ring (newest first).
class AppLogViewerPage extends StatefulWidget {
  const AppLogViewerPage({super.key});

  @override
  State<AppLogViewerPage> createState() => _AppLogViewerPageState();
}

class _AppLogViewerPageState extends State<AppLogViewerPage> {
  static final _time = DateFormat('HH:mm:ss');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPage(
      title: '诊断日志',
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppButton(
          label: '清空',
          variant: AppButtonVariant.ghost,
          onPressed: () {
            AppLog.instance.clear();
          },
        ),
      ],
      body: ListenableBuilder(
        listenable: AppLog.instance,
        builder: (context, _) {
          final count = AppLog.instance.length;
          if (count == 0) {
            return const Center(
              child: AppText(
                '暂无日志',
                role: AppTextRole.caption,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
            itemCount: count,
            itemBuilder: (context, index) {
              final entry = AppLog.instance.entryAtNewestFirst(index);
              if (entry == null) return const SizedBox.shrink();
              return _LogRow(
                entry: entry,
                timeLabel: _time.format(entry.time),
                accent: _levelColor(theme, entry.level),
                onCopy: () => _copyEntry(context, entry),
              );
            },
          );
        },
      ),
    );
  }

  Color _levelColor(ThemeData theme, AppLogLevel level) => switch (level) {
        AppLogLevel.info => theme.colorScheme.primary,
        AppLogLevel.warning => theme.colorScheme.tertiary,
        AppLogLevel.error => theme.colorScheme.error,
      };

  Future<void> _copyEntry(BuildContext context, AppLogEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.fullText));
    if (!context.mounted) return;
    showAppToast(context, '已复制');
  }
}

class _LogRow extends StatefulWidget {
  const _LogRow({
    required this.entry,
    required this.timeLabel,
    required this.accent,
    required this.onCopy,
  });

  final AppLogEntry entry;
  final String timeLabel;
  final Color accent;
  final VoidCallback onCopy;

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hasDetails = entry.error != null || entry.stackTrace != null;
    final subtitle = hasDetails && !_expanded
        ? '${entry.message}…'
        : entry.fullText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
        onLongPress: widget.onCopy,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceXs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(right: AppTheme.spaceSm),
                decoration: BoxDecoration(
                  color: widget.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        AppText(
                          widget.timeLabel,
                          role: AppTextRole.caption,
                        ),
                        const SizedBox(width: AppTheme.spaceXs),
                        AppText(
                          entry.level.label,
                          role: AppTextRole.caption,
                        ),
                        const SizedBox(width: AppTheme.spaceXs),
                        Flexible(
                          child: AppText(
                            entry.tag,
                            role: AppTextRole.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      subtitle,
                      role: AppTextRole.body,
                      maxLines: _expanded ? null : 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}