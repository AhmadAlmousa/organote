import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../app/mobile_shell.dart';
import '../../app/overlay_route.dart';
import '../../state/app_providers.dart';
import '../../state/library_provider.dart';
import '../../state/search_controller.dart';
import '../../theme/color_tokens.dart';
import '../../theme/density.dart';
import '../../theme/motion.dart';
import '../../util/category_color.dart';
import '../../widgets/note_card.dart';
import '../../widgets/org_chip.dart';
import '../../widgets/org_empty_state.dart';
import '../../widgets/org_fab.dart';
import '../../widgets/org_icon_button.dart';
import '../../widgets/org_search_bar.dart';
import '../../widgets/org_toast.dart';
import '../../widgets/wordmark.dart';
import '../note_editor/note_editor_screen.dart';
import '../note_viewer/note_viewer_screen.dart';
import '../settings/phase9_screens.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchOpen = false;

  @override
  void dispose() {
    _queryController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
      if (_queryController.text.isNotEmpty) {
        _queryController.clear();
        ref.read(noteSearchProvider.notifier).setQuery('');
      }
    }
  }

  void _openComplianceReview() {
    Navigator.of(context).push(
      OrgOverlayRoute<void>(builder: (_) => const ComplianceReviewScreen()),
    );
  }

  Future<void> _togglePinned(Note note) async {
    await ref.read(noteRepositoryProvider).setPinned(note.id, !note.isPinned);
  }

  Future<void> _toggleFavorite(Note note) async {
    await ref
        .read(noteRepositoryProvider)
        .setFavorite(note.id, !note.isFavorite);
  }

  void _openNote(Note note) {
    Navigator.of(context).push(
      OrgOverlayRoute<void>(builder: (_) => NoteViewerScreen(noteId: note.id)),
    );
  }

  void _createNote() {
    Navigator.of(
      context,
    ).push(OrgOverlayRoute<void>(builder: (_) => const NoteEditorScreen()));
  }

  void _openCategoryEditor(String selectedPath) {
    final searchNotifier = ref.read(noteSearchProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategoryEditorSheet(
        selectedPath: selectedPath,
        onSelectedPathChanged: searchNotifier.setCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final library = ref.watch(librarySnapshotProvider);
    final search = ref.watch(noteSearchProvider);
    final searchNotifier = ref.read(noteSearchProvider.notifier);
    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;

    final notes = library.notes;
    final byPin = [...notes]
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    final visible = search.apply(byPin).toList();

    final shellInset = OrgMobileChrome.bottomInsetOf(context);
    final listBottomPad = shellInset + (compact ? 16 : 24);
    final fabBottom = shellInset + 14;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _HomeHeader(
                    compliance: library.complianceSummary.activeCount,
                    onToggleSearch: _toggleSearch,
                    onOpenCompliance: _openComplianceReview,
                    searchOpen: _searchOpen,
                  ),
                ),
                SliverToBoxAdapter(
                  child: AnimatedSize(
                    duration: OrgDurations.toggle,
                    curve: OrgCurves.easeOutQuint,
                    alignment: Alignment.topCenter,
                    child: _searchOpen
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 12 : 18,
                              0,
                              compact ? 12 : 18,
                              10,
                            ),
                            child: OrgSearchBar(
                              controller: _queryController,
                              focusNode: _searchFocusNode,
                              onChanged: searchNotifier.setQuery,
                              onFilter: () => _showFilterSheet(
                                context,
                                library: library,
                                search: search,
                                searchNotifier: searchNotifier,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CategoryRow(
                    categories: library.categories,
                    notes: notes,
                    selected: search.category,
                    onSelect: searchNotifier.setCategory,
                    onEdit: () => _openCategoryEditor(search.category),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 18,
                      18,
                      compact ? 12 : 18,
                      8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          visible.isEmpty
                              ? 'Nothing here yet'
                              : '${visible.length} note${visible.length == 1 ? '' : 's'}',
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(color: palette.text),
                        ),
                        const Spacer(),
                        Text(
                          'Recent first',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: palette.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  SliverToBoxAdapter(
                    child: OrgEmptyState(
                      emoji: '∅',
                      message: search.query.isEmpty
                          ? 'No notes yet'
                          : 'Nothing matches "${search.query}"',
                      subtitle: search.query.isEmpty
                          ? 'Tap the + button to create your first note.'
                          : 'Try a different word or clear the search.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 18,
                      0,
                      compact ? 12 : 18,
                      listBottomPad,
                    ),
                    sliver: SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: compact ? 6 : 12),
                      itemBuilder: (context, index) {
                        final note = visible[index];
                        final template = _findTemplate(
                          library.templates,
                          note.templateId,
                        );
                        final category = _findCategory(
                          library.categories,
                          note.categoryPath,
                        );
                        return NoteCard(
                          note: note,
                          template: template,
                          category: category,
                          onOpen: () => _openNote(note),
                          onTogglePin: () => _togglePinned(note),
                          onToggleFavorite: () => _toggleFavorite(note),
                        );
                      },
                    ),
                  ),
              ],
            ),
            Positioned(
              right: 18,
              bottom: fabBottom,
              child: OrgFab(
                onPressed: _createNote,
                tooltip: 'New note',
                size: compact ? 52 : 60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Template? _findTemplate(List<Template> templates, String? id) {
    if (id == null) return null;
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  Category? _findCategory(List<Category> categories, String path) {
    if (path.isEmpty) return null;
    for (final c in categories) {
      if (c.path == path) return c;
    }
    return null;
  }

  Future<void> _showFilterSheet(
    BuildContext context, {
    required LibrarySnapshot library,
    required NoteSearchState search,
    required NoteSearchNotifier searchNotifier,
  }) async {
    final palette = OrgPaletteScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.borderStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Category',
              style: TextStyle(
                color: palette.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChipButton(
                  label: 'All',
                  active: search.category == kAllCategoryPath,
                  color: palette.accent,
                  onTap: () => searchNotifier.setCategory(kAllCategoryPath),
                ),
                for (final category in library.categories)
                  _FilterChipButton(
                    label: category.name,
                    active: search.category == category.path,
                    color: accentForHue(
                      hueOfCategory(category, fallbackHue: palette.accentHue),
                    ),
                    onTap: () => searchNotifier.setCategory(category.path),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      searchNotifier.clear();
                      _queryController.clear();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.text,
                      side: BorderSide(color: palette.borderStrong),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: palette.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      avatar: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      labelStyle: TextStyle(
        color: active ? palette.onAccent : palette.textSecondary,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      backgroundColor: active ? color : palette.bgSecondary,
      side: BorderSide(color: active ? Colors.transparent : palette.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.compliance,
    required this.onToggleSearch,
    required this.onOpenCompliance,
    required this.searchOpen,
  });

  final int compliance;
  final VoidCallback onToggleSearch;
  final VoidCallback onOpenCompliance;
  final bool searchOpen;

  @override
  Widget build(BuildContext context) {
    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 18,
        compact ? 6 : 14,
        compact ? 12 : 18,
        compact ? 6 : 12,
      ),
      child: Row(
        children: [
          Wordmark(size: compact ? 18 : 20),
          const Spacer(),
          OrgIconButton(
            icon: searchOpen
                ? Icons.search_off_rounded
                : Icons.search_rounded,
            size: 38,
            tooltip: searchOpen ? 'Close search' : 'Search',
            onPressed: onToggleSearch,
          ),
          const SizedBox(width: 8),
          _NotificationBell(
            compliance: compliance,
            onPressed: onOpenCompliance,
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.compliance,
    required this.onPressed,
  });

  final int compliance;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final hasIssues = compliance > 0;
    final label = compliance > 99 ? '99+' : '$compliance';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OrgIconButton(
          icon: hasIssues
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          size: 38,
          tooltip: hasIssues
              ? '$compliance compliance issue${compliance == 1 ? '' : 's'}'
              : 'No notifications',
          foreground: hasIssues ? palette.danger : null,
          onPressed: onPressed,
        ),
        if (hasIssues)
          Positioned(
            right: -2,
            top: -2,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: label.length > 1 ? 4 : 0,
                ),
                decoration: BoxDecoration(
                  color: palette.danger,
                  shape: label.length > 1
                      ? BoxShape.rectangle
                      : BoxShape.circle,
                  borderRadius: label.length > 1
                      ? BorderRadius.circular(999)
                      : null,
                  border: Border.all(color: palette.bg, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: palette.onAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.categories,
    required this.notes,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
  });

  final List<Category> categories;
  final List<Note> notes;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;

    final all = OrgChip(
      label: 'All',
      active: selected == kAllCategoryPath,
      count: notes.length,
      hueColor: palette.accent,
      softColor: palette.accentSoft,
      onTap: () => onSelect(kAllCategoryPath),
    );

    final chips = <Widget>[
      all,
      for (final cat in categories)
        OrgChip(
          label: cat.name,
          active: selected == cat.path,
          count: notes.where((n) => n.categoryPath == cat.path).length,
          hueColor: accentForHue(
            hueOfCategory(cat, fallbackHue: palette.accentHue),
          ),
          softColor: softForHue(
            hueOfCategory(cat, fallbackHue: palette.accentHue),
            0.18,
          ),
          icon: _categoryIcon(cat.name),
          onTap: () => onSelect(cat.path),
        ),
      _EditCategoriesChip(palette: palette, onTap: onEdit),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, index) => Center(child: chips[index]),
        ),
      ),
    );
  }

  IconData? _categoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('work')) return Icons.work_outline_rounded;
    if (lower.contains('personal')) return Icons.favorite_outline_rounded;
    if (lower.contains('server')) return Icons.storage_rounded;
    if (lower.contains('home')) return Icons.cottage_rounded;
    if (lower.contains('travel')) return Icons.flight_rounded;
    return null;
  }
}

class _EditCategoriesChip extends StatelessWidget {
  const _EditCategoriesChip({required this.palette, required this.onTap});

  final OrgPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 14, color: palette.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Edit',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryEditorSheet extends ConsumerStatefulWidget {
  const _CategoryEditorSheet({
    required this.selectedPath,
    required this.onSelectedPathChanged,
  });

  final String selectedPath;
  final ValueChanged<String> onSelectedPathChanged;

  @override
  ConsumerState<_CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<_CategoryEditorSheet> {
  final Set<String> _busyPaths = <String>{};
  late String _selectedPath = widget.selectedPath;

  Future<void> _openForm({Category? category}) async {
    final result = await showModalBottomSheet<_CategoryFormResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategoryFormSheet(category: category),
    );
    if (result == null || !mounted) return;
    await _saveCategory(category, result);
  }

  Future<void> _saveCategory(
    Category? category,
    _CategoryFormResult result,
  ) async {
    final busyPath = category?.path ?? '__new__';
    if (_busyPaths.contains(busyPath)) return;
    setState(() => _busyPaths.add(busyPath));
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final categories = ref.read(librarySnapshotProvider).categories;
      final nextPath = _uniqueCategoryPath(
        result.name,
        categories,
        original: category,
      );
      final nextColor = _hexFromHue(result.hue);
      if (category != null && category.path != nextPath) {
        await repo.moveCategory(category.path, nextPath);
      }
      final saved = await repo.saveCategory(
        Category(
          path: nextPath,
          name: _nameFromPath(nextPath),
          parentPath: _parentPathOf(nextPath),
          colorHex: nextColor,
          noteCount: category?.noteCount ?? 0,
        ),
      );
      final selectedAfterMove = category == null
          ? saved.path
          : _selectedPathAfterMove(_selectedPath, category.path, saved.path);
      if (selectedAfterMove != _selectedPath) {
        _setSelectedPath(selectedAfterMove);
      }
      if (!mounted) return;
      showOrgToast(
        context,
        message: category == null ? 'Category created' : 'Category updated',
        icon: Icons.sell_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Category save failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) {
        setState(() => _busyPaths.remove(busyPath));
      }
    }
  }

  Future<void> _deleteCategory(Category category) async {
    if (_busyPaths.contains(category.path)) return;
    final confirmed = await _confirmDelete(category);
    if (confirmed != true || !mounted) return;
    setState(() => _busyPaths.add(category.path));
    try {
      await ref.read(categoryRepositoryProvider).deleteCategory(category.path);
      if (_selectionInside(_selectedPath, category.path)) {
        _setSelectedPath(kAllCategoryPath);
      }
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Category moved to trash',
        icon: Icons.delete_outline_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Delete failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) {
        setState(() => _busyPaths.remove(category.path));
      }
    }
  }

  Future<bool?> _confirmDelete(Category category) {
    final palette = OrgPaletteScope.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Delete ${category.name}?',
            style: TextStyle(color: palette.text, fontWeight: FontWeight.w900),
          ),
          content: Text(
            category.noteCount == 0
                ? 'The category folder will move to trash.'
                : '${category.noteCount} note${category.noteCount == 1 ? '' : 's'} will move with this category.',
            style: TextStyle(color: palette.textSecondary, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _setSelectedPath(String path) {
    setState(() => _selectedPath = path);
    widget.onSelectedPathChanged(path);
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final categories = ref.watch(librarySnapshotProvider).categories;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: categories.isEmpty ? 0.38 : 0.62,
      minChildSize: 0.32,
      maxChildSize: 0.88,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: palette.borderStrong,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            Text(
                              'Categories',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: palette.text,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      OrgIconButton(
                        icon: Icons.add_rounded,
                        tooltip: 'New category',
                        onPressed: () => _openForm(),
                      ),
                      const SizedBox(width: 6),
                      OrgIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: categories.isEmpty
                      ? OrgEmptyState(
                          emoji: '+',
                          message: 'No categories yet',
                          subtitle: 'Create one to group notes by folder.',
                          action: FilledButton.icon(
                            onPressed: () => _openForm(),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('New category'),
                          ),
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                          itemCount: categories.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return _CategoryEditorRow(
                              category: category,
                              active: _selectedPath == category.path,
                              busy: _busyPaths.contains(category.path),
                              onSelect: () => _setSelectedPath(category.path),
                              onEdit: () => _openForm(category: category),
                              onDelete: () => _deleteCategory(category),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryEditorRow extends StatelessWidget {
  const _CategoryEditorRow({
    required this.category,
    required this.active,
    required this.busy,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final bool active;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final hue = hueOfCategory(category, fallbackHue: palette.accentHue);
    final accent = accentForHue(hue);
    return AnimatedContainer(
      duration: OrgDurations.toggle,
      curve: OrgCurves.spring,
      decoration: BoxDecoration(
        color: active ? softForHue(hue, 0.18) : palette.bgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? accent : palette.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: busy ? null : onSelect,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withAlpha(80),
                      blurRadius: 12,
                      spreadRadius: -3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${category.noteCount} note${category.noteCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                )
              else ...[
                OrgIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Edit category',
                  size: 34,
                  onPressed: onEdit,
                ),
                OrgIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete category',
                  size: 34,
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet({this.category});

  final Category? category;

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late double _hue;

  @override
  void initState() {
    super.initState();
    _hue = widget.category == null
        ? OrgAccents.mint.hue
        : hueOfCategory(widget.category!, fallbackHue: OrgAccents.mint.hue);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final accent = accentForHue(_hue);
    final canSave = _nameController.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.borderStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.category == null ? 'New category' : 'Edit category',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
                decoration: BoxDecoration(
                  color: palette.bgSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  cursorColor: accent,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Servers',
                    hintStyle: TextStyle(color: palette.textTertiary),
                    isCollapsed: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Color',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withAlpha(85),
                          blurRadius: 14,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFFFF6B6B),
                              Color(0xFFFFD166),
                              Color(0xFF06D6A0),
                              Color(0xFF118AB2),
                              Color(0xFF9D4EDD),
                              Color(0xFFFF6B6B),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        thumbColor: accent,
                        overlayColor: accent.withAlpha(40),
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                      ),
                      child: Slider(
                        min: 0,
                        max: 360,
                        value: _hue,
                        onChanged: (value) => setState(() => _hue = value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.text,
                        side: BorderSide(color: palette.borderStrong),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: canSave
                          ? () => Navigator.of(context).pop(
                              _CategoryFormResult(
                                name: _nameController.text.trim(),
                                hue: _hue,
                              ),
                            )
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: palette.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFormResult {
  const _CategoryFormResult({required this.name, required this.hue});

  final String name;
  final double hue;
}

String _uniqueCategoryPath(
  String name,
  List<Category> categories, {
  Category? original,
}) {
  final parent = original == null ? null : _parentPathOf(original.path);
  final slug = _slugCategoryName(name);
  final base = parent == null ? slug : '$parent/$slug';
  final taken = categories
      .map((category) => category.path)
      .where((path) => path != original?.path)
      .toSet();
  if (!taken.contains(base)) return base;
  var suffix = 2;
  while (taken.contains('$base-$suffix')) {
    suffix += 1;
  }
  return '$base-$suffix';
}

String _slugCategoryName(String name) {
  final slug = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'category' : slug;
}

String _nameFromPath(String path) {
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  return parts.isEmpty ? path : parts.last;
}

String? _parentPathOf(String path) {
  final index = path.lastIndexOf('/');
  if (index <= 0) return null;
  return path.substring(0, index);
}

String _selectedPathAfterMove(String selected, String from, String to) {
  if (selected == from) return to;
  if (selected.startsWith('$from/')) {
    return '$to/${selected.substring(from.length + 1)}';
  }
  return selected;
}

bool _selectionInside(String selected, String path) {
  return selected == path || selected.startsWith('$path/');
}

String _hexFromHue(double hue) {
  final argb = accentForHue(hue).toARGB32();
  final red = ((argb >> 16) & 0xFF).toRadixString(16).padLeft(2, '0');
  final green = ((argb >> 8) & 0xFF).toRadixString(16).padLeft(2, '0');
  final blue = (argb & 0xFF).toRadixString(16).padLeft(2, '0');
  return '#${red.toUpperCase()}${green.toUpperCase()}${blue.toUpperCase()}';
}
