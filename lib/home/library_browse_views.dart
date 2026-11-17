import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/project_folder.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_cover_tile.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_shaped_avatar.dart';
import 'package:anoworld/home/library_display_prefs.dart';
import 'package:anoworld/home/library_selection.dart';
import 'package:flutter/material.dart';

class LibraryBrowseViews extends StatelessWidget {
  const LibraryBrowseViews({
    super.key,
    required this.viewMode,
    required this.avatarShape,
    required this.folders,
    required this.projects,
    required this.selection,
    required this.onOpenFolder,
    required this.onOpenProject,
    required this.onFolderMenu,
    required this.onProjectMenu,
    required this.formatUpdated,
  });

  final LibraryViewMode viewMode;
  final LibraryAvatarShape avatarShape;
  final List<ProjectFolder> folders;
  final List<ProjectSummary> projects;
  final LibrarySelectionController selection;
  final ValueChanged<ProjectFolder> onOpenFolder;
  final ValueChanged<ProjectSummary> onOpenProject;
  final ValueChanged<ProjectFolder> onFolderMenu;
  final ValueChanged<ProjectSummary> onProjectMenu;
  final String Function(DateTime) formatUpdated;

  EdgeInsets _listPadding(BuildContext context) {
    final mediaBottom = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(
      AppTheme.pagePadding,
      AppTheme.spaceXs,
      AppTheme.pagePadding,
      AppTheme.pagePadding + mediaBottom + 72,
    );
  }

  AppAvatarGeometry get _geometry => switch (avatarShape) {
        LibraryAvatarShape.circle => AppAvatarGeometry.circle,
        LibraryAvatarShape.square => AppAvatarGeometry.square,
        LibraryAvatarShape.rectangle => AppAvatarGeometry.rectangle,
      };

  String _folderSubtitle(ProjectFolder folder) {
    final parts = [
      if (folder.childFolderCount > 0) '${folder.childFolderCount} 个文件夹',
      if (folder.projectCount > 0) '${folder.projectCount} 个故事',
    ];
    return parts.isEmpty ? '空文件夹' : parts.join(' · ');
  }

  Widget _selectionOrAvatar(
    BuildContext context, {
    required bool selectionMode,
    required bool selected,
    required Widget avatar,
  }) {
    if (!selectionMode) return avatar;
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      selected ? Icons.check_circle : Icons.circle_outlined,
      color: selected ? scheme.primary : scheme.outline,
    );
  }

  Widget _folderAvatar(BuildContext context, {required bool compact}) {
    final scheme = Theme.of(context).colorScheme;
    final size = compact ? 40.0 : 56.0;
    return AppShapedAvatar.fromGeometry(
      width: size,
      geometry: compact ? AppAvatarGeometry.circle : _geometry,
      backgroundColor: scheme.secondaryContainer,
      child: Icon(
        Icons.folder,
        color: scheme.onSecondaryContainer,
        size: compact ? 20 : 22,
      ),
    );
  }

  Widget _projectAvatar(
    BuildContext context, {
    required String title,
    required bool compact,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final size = compact ? 40.0 : 56.0;
    final letter = title.isEmpty ? '?' : title.characters.first;
    return AppShapedAvatar.fromGeometry(
      width: size,
      geometry: compact ? AppAvatarGeometry.circle : _geometry,
      backgroundColor: scheme.primary.withValues(alpha: 0.18),
      child: Text(
        letter,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 14 : 18,
        ),
      ),
    );
  }

  Widget _folderCover(BuildContext context, {required bool compact}) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Center(
        child: Icon(
          Icons.folder,
          size: compact ? 36 : 48,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _projectCover(
    BuildContext context,
    String title, {
    required bool compact,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final letter = title.isEmpty ? '?' : title.characters.first;
    return ColoredBox(
      color: scheme.primary.withValues(alpha: 0.16),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 28 : 36,
          ),
        ),
      ),
    );
  }

  Widget _selectionBadge(BuildContext context, bool selected) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 8,
      right: 8,
      child: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? scheme.primary : scheme.outline,
      ),
    );
  }

  Widget _moreOverlay(VoidCallback onPressed) {
    return Positioned(
      top: 4,
      right: 4,
      child: AppIconButton(
        icon: Icons.more_vert,
        tooltip: '更多',
        onPressed: onPressed,
      ),
    );
  }

  void _onFolderTap(ProjectFolder folder) {
    if (selection.selectionMode) {
      selection.toggle(folder.id);
    } else {
      onOpenFolder(folder);
    }
  }

  void _onProjectTap(ProjectSummary project) {
    if (selection.selectionMode) {
      selection.toggle(project.id);
    } else {
      onOpenProject(project);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (viewMode) {
      LibraryViewMode.list => _detailList(context),
      LibraryViewMode.simpleList => _simpleList(context),
      LibraryViewMode.grid => _grid(context, compact: false),
      LibraryViewMode.compactGrid => _grid(context, compact: true),
    };
  }

  Widget _detailList(BuildContext context) {
    final selectionMode = selection.selectionMode;
    final itemCount = folders.length + projects.length;
    return ListView.separated(
      padding: _listPadding(context),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spaceSm),
      itemBuilder: (context, index) {
        if (index < folders.length) {
          final folder = folders[index];
          final selected = selection.isSelected(folder.id);
          return AppListTile(
            title: folder.name,
            subtitle: _folderSubtitle(folder),
            selected: selectionMode && selected,
            leading: _selectionOrAvatar(
              context,
              selectionMode: selectionMode,
              selected: selected,
              avatar: _folderAvatar(context, compact: false),
            ),
            trailing: selectionMode
                ? null
                : AppIconButton(
                    icon: Icons.more_vert,
                    tooltip: '更多',
                    onPressed: () => onFolderMenu(folder),
                  ),
            onTap: () => _onFolderTap(folder),
            onLongPress: () => selection.toggle(folder.id),
          );
        }
        final project = projects[index - folders.length];
        final selected = selection.isSelected(project.id);
        return AppListTile(
          title: project.title,
          subtitle: formatUpdated(project.updatedAt),
          selected: selectionMode && selected,
          leading: _selectionOrAvatar(
            context,
            selectionMode: selectionMode,
            selected: selected,
            avatar: _projectAvatar(
              context,
              title: project.title,
              compact: false,
            ),
          ),
          trailing: selectionMode
              ? null
              : AppIconButton(
                  icon: Icons.more_vert,
                  tooltip: '更多',
                  onPressed: () => onProjectMenu(project),
                ),
          onTap: () => _onProjectTap(project),
          onLongPress: () => selection.toggle(project.id),
        );
      },
    );
  }

  Widget _simpleList(BuildContext context) {
    const rowHeight = 60.0;
    const rowGap = 8.0;
    final selectionMode = selection.selectionMode;
    final itemCount = folders.length + projects.length;
    return ListView.builder(
      padding: _listPadding(context),
      itemCount: itemCount,
      itemExtent: rowHeight + rowGap,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          final folder = folders[index];
          final selected = selection.isSelected(folder.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: rowGap),
            child: SizedBox(
              height: rowHeight,
              child: AppListTile(
                title: folder.name,
                selected: selectionMode && selected,
                leading: _selectionOrAvatar(
                  context,
                  selectionMode: selectionMode,
                  selected: selected,
                  avatar: _folderAvatar(context, compact: true),
                ),
                trailing: selectionMode
                    ? null
                    : Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                onTap: () => _onFolderTap(folder),
                onLongPress: () => selection.toggle(folder.id),
              ),
            ),
          );
        }
        final project = projects[index - folders.length];
        final selected = selection.isSelected(project.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: rowGap),
          child: SizedBox(
            height: rowHeight,
            child: AppListTile(
              title: project.title,
              selected: selectionMode && selected,
              leading: _selectionOrAvatar(
                context,
                selectionMode: selectionMode,
                selected: selected,
                avatar: _projectAvatar(
                  context,
                  title: project.title,
                  compact: true,
                ),
              ),
              trailing: selectionMode
                  ? null
                  : AppIconButton(
                      icon: Icons.more_vert,
                      tooltip: '更多',
                      onPressed: () => onProjectMenu(project),
                    ),
              onTap: () => _onProjectTap(project),
              onLongPress: () => selection.toggle(project.id),
            ),
          ),
        );
      },
    );
  }

  Widget _grid(BuildContext context, {required bool compact}) {
    final selectionMode = selection.selectionMode;
    final itemCount = folders.length + projects.length;
    final minTile = compact ? 110.0 : 140.0;
    final spacing = compact ? 8.0 : 10.0;
    final aspect = compact ? 0.65 : 0.72;

    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppTheme.pagePadding * 2;
        final contentWidth =
            (constraints.maxWidth - inset).clamp(0.0, double.infinity);
        var columns =
            ((contentWidth + spacing) / (minTile + spacing)).floor().clamp(1, 12);
        if (constraints.maxWidth >= 600 && columns > 1 && columns.isOdd) {
          columns--;
        }
        return GridView.builder(
          padding: _listPadding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: aspect,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index < folders.length) {
              final folder = folders[index];
              final selected = selection.isSelected(folder.id);
              return AppCoverTile(
                compact: compact,
                title: folder.name,
                subtitle: _folderSubtitle(folder),
                selected: selectionMode && selected,
                cover: _folderCover(context, compact: compact),
                overlay: selectionMode
                    ? _selectionBadge(context, selected)
                    : _moreOverlay(() => onFolderMenu(folder)),
                onTap: () => _onFolderTap(folder),
                onLongPress: () => selection.toggle(folder.id),
              );
            }
            final project = projects[index - folders.length];
            final selected = selection.isSelected(project.id);
            return AppCoverTile(
              compact: compact,
              title: project.title,
              subtitle: formatUpdated(project.updatedAt),
              selected: selectionMode && selected,
              cover: _projectCover(context, project.title, compact: compact),
              overlay: selectionMode
                  ? _selectionBadge(context, selected)
                  : _moreOverlay(() => onProjectMenu(project)),
              onTap: () => _onProjectTap(project),
              onLongPress: () => selection.toggle(project.id),
            );
          },
        );
      },
    );
  }
}
