import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/project_folder.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_cover_tile.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_press_scale.dart';
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
    this.onCreate,
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

  /// When set, a story-shaped “add” tile is appended after folders/projects.
  final VoidCallback? onCreate;

  EdgeInsets _listPadding(BuildContext context, {bool horizontal = false}) {
    final mediaBottom = MediaQuery.paddingOf(context).bottom;
    final h = horizontal ? AppTheme.pagePadding : 0.0;
    return EdgeInsets.fromLTRB(
      h,
      AppTheme.spaceXs,
      h,
      AppTheme.pagePadding + mediaBottom + 72,
    );
  }

  AppAvatarGeometry get _geometry => switch (avatarShape) {
        LibraryAvatarShape.circle => AppAvatarGeometry.circle,
        LibraryAvatarShape.square => AppAvatarGeometry.square,
        LibraryAvatarShape.rectangle => AppAvatarGeometry.rectangle,
      };

  bool get _showCreate => onCreate != null;

  int get _baseCount => folders.length + projects.length;

  int get _itemCount => _baseCount + (_showCreate ? 1 : 0);

  bool _isCreateIndex(int index) => _showCreate && index == _baseCount;

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

  Widget _createCover(BuildContext context, {required bool compact}) {
    final scheme = Theme.of(context).colorScheme;
    // Icon only — tile Material supplies the fill so Ink hover/press shows.
    return Center(
      child: Icon(
        Icons.add,
        size: compact ? 36 : 48,
        color: scheme.onSurfaceVariant,
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

  static const createControlKey = ValueKey<String>('library_create');

  Widget _createListTile(BuildContext context, {required bool compact}) {
    final scheme = Theme.of(context).colorScheme;
    final geometry = compact ? AppAvatarGeometry.circle : _geometry;
    final size = compact ? 40.0 : 56.0;
    final height = geometry.heightFor(size);
    final radius = geometry.radiusFor(size);
    final ShapeBorder border = switch (geometry) {
      AppAvatarGeometry.circle => const CircleBorder(),
      AppAvatarGeometry.square || AppAvatarGeometry.rectangle =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pagePadding,
        vertical: AppTheme.spaceXs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: '添加',
          child: AppPressScale(
            child: Material(
              key: createControlKey,
              color: scheme.surfaceContainerHighest,
              shape: border,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onCreate,
                customBorder: border,
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return scheme.onSurface.withValues(alpha: 0.14);
                  }
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)) {
                    return scheme.onSurface.withValues(alpha: 0.08);
                  }
                  return null;
                }),
                child: SizedBox(
                  width: size,
                  height: height,
                  child: Icon(
                    Icons.add,
                    color: scheme.onSurfaceVariant,
                    size: compact ? 22 : 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailList(BuildContext context) {
    final selectionMode = selection.selectionMode;
    return ListView.separated(
      padding: _listPadding(context),
      itemCount: _itemCount,
      separatorBuilder: (_, _) => const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (_isCreateIndex(index)) {
          return _createListTile(context, compact: false);
        }
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
    final selectionMode = selection.selectionMode;
    return ListView.builder(
      padding: _listPadding(context),
      itemCount: _itemCount,
      itemBuilder: (context, index) {
        if (_isCreateIndex(index)) {
          return _createListTile(context, compact: true);
        }
        if (index < folders.length) {
          final folder = folders[index];
          final selected = selection.isSelected(folder.id);
          return AppListTile(
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
          );
        }
        final project = projects[index - folders.length];
        final selected = selection.isSelected(project.id);
        return AppListTile(
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
        );
      },
    );
  }

  Widget _grid(BuildContext context, {required bool compact}) {
    final selectionMode = selection.selectionMode;
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
          padding: _listPadding(context, horizontal: true),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: aspect,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: _itemCount,
          itemBuilder: (context, index) {
            if (_isCreateIndex(index)) {
              return KeyedSubtree(
                key: createControlKey,
                child: AppCoverTile(
                  compact: compact,
                  cover: _createCover(context, compact: compact),
                  onTap: onCreate,
                  semanticLabel: '添加',
                ),
              );
            }
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
