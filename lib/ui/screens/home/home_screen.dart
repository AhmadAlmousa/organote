import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../state/app_providers.dart';
import '../../state/library_provider.dart';
import '../../state/search_controller.dart';
import '../../theme/color_tokens.dart';
import '../../theme/density.dart';
import '../../util/category_color.dart';
import '../../widgets/note_card.dart';
import '../../widgets/org_chip.dart';
import '../../widgets/org_empty_state.dart';
import '../../widgets/org_fab.dart';
import '../../widgets/org_icon_button.dart';
import '../../widgets/org_search_bar.dart';
import '../../widgets/wordmark.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Note "${note.title}" opens in Phase 3 (viewer).'),
      ),
    );
  }

  void _createNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New-note editor lands in Phase 4.')),
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

    return Scaffold(
      backgroundColor: palette.bg,
      floatingActionButton: compact
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 14, right: 4),
              child: OrgFab(onPressed: _createNote, tooltip: 'New note'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _HomeHeader(
                    notesCount: notes.length,
                    compliance: library.complianceSummary.activeCount,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 18,
                    ),
                    child: OrgSearchBar(
                      controller: _queryController,
                      onChanged: searchNotifier.setQuery,
                      onFilter: () => _showFilterSheet(context),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CategoryRow(
                    categories: library.categories,
                    notes: notes,
                    selected: search.category,
                    onSelect: searchNotifier.setCategory,
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
                      compact ? 24 : 110,
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
            if (compact)
              Positioned(
                right: 18,
                bottom: 18,
                child: OrgFab(
                  onPressed: _createNote,
                  tooltip: 'New note',
                  size: 52,
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

  Future<void> _showFilterSheet(BuildContext context) async {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Advanced filtering arrives with the templates picker in Phase 8.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.notesCount, required this.compliance});

  final int notesCount;
  final int compliance;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 18,
        compact ? 6 : 14,
        compact ? 12 : 18,
        compact ? 4 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Wordmark(size: compact ? 18 : 20),
              const Spacer(),
              if (compliance > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CompliancePill(count: compliance),
                ),
              OrgIconButton(
                icon: Icons.search_rounded,
                size: 38,
                tooltip: 'Quick search',
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              OrgIconButton(
                icon: Icons.notifications_none_rounded,
                size: 38,
                tooltip: 'Notifications',
                onPressed: () {},
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Text(
              'Good morning,',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              notesCount == 0
                  ? 'fresh canvas — make something.'
                  : '$notesCount note${notesCount == 1 ? '' : 's'} ready to flow.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: palette.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.018,
              ),
            ),
          ],
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _CompliancePill extends StatelessWidget {
  const _CompliancePill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.danger.withAlpha(40),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.danger.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: palette.danger, size: 14),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: palette.danger,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.categories,
    required this.notes,
    required this.selected,
    required this.onSelect,
  });

  final List<Category> categories;
  final List<Note> notes;
  final String selected;
  final ValueChanged<String> onSelect;

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
      _EditCategoriesChip(palette: palette),
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
  const _EditCategoriesChip({required this.palette});

  final OrgPalette palette;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category editor lands in Phase 8.')),
        );
      },
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
