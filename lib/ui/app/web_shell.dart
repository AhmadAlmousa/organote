import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../domain/models/models.dart';
import '../screens/note_editor/note_editor_screen.dart';
import '../screens/note_viewer/note_viewer_screen.dart';
import '../screens/template_builder/template_builder_screen.dart';
import '../state/app_providers.dart';
import '../state/library_provider.dart';
import '../state/search_controller.dart';
import '../theme/color_tokens.dart';
import '../theme/density.dart';
import '../theme/motion.dart';
import '../theme/theme_controller.dart';
import '../util/category_color.dart';
import '../util/relative_time.dart';
import '../widgets/org_icon_button.dart';
import '../widgets/wordmark.dart';
import 'mobile_shell.dart';
import 'overlay_route.dart';

enum _DraftKind { none, note, template }

class _SelectTabIntent extends Intent {
  const _SelectTabIntent(this.tab);

  final OrgTabId tab;
}

class _StartDraftIntent extends Intent {
  const _StartDraftIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _DismissDraftIntent extends Intent {
  const _DismissDraftIntent();
}

class WebShell extends ConsumerStatefulWidget {
  const WebShell({
    super.key,
    required this.home,
    required this.templates,
    required this.settings,
  });

  final Widget home;
  final Widget templates;
  final Widget settings;

  @override
  ConsumerState<WebShell> createState() => _WebShellState();
}

class _WebShellState extends ConsumerState<WebShell> {
  static const Map<ShortcutActivator, Intent>
  _desktopShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.digit1, control: true): _SelectTabIntent(
      OrgTabId.home,
    ),
    SingleActivator(LogicalKeyboardKey.digit1, meta: true): _SelectTabIntent(
      OrgTabId.home,
    ),
    SingleActivator(LogicalKeyboardKey.digit2, control: true): _SelectTabIntent(
      OrgTabId.templates,
    ),
    SingleActivator(LogicalKeyboardKey.digit2, meta: true): _SelectTabIntent(
      OrgTabId.templates,
    ),
    SingleActivator(LogicalKeyboardKey.digit3, control: true): _SelectTabIntent(
      OrgTabId.settings,
    ),
    SingleActivator(LogicalKeyboardKey.digit3, meta: true): _SelectTabIntent(
      OrgTabId.settings,
    ),
    SingleActivator(LogicalKeyboardKey.keyN, control: true):
        _StartDraftIntent(),
    SingleActivator(LogicalKeyboardKey.keyN, meta: true): _StartDraftIntent(),
    SingleActivator(LogicalKeyboardKey.keyK, control: true):
        _FocusSearchIntent(),
    SingleActivator(LogicalKeyboardKey.keyK, meta: true): _FocusSearchIntent(),
    SingleActivator(LogicalKeyboardKey.escape): _DismissDraftIntent(),
  };

  final TextEditingController _noteQueryController = TextEditingController();
  final TextEditingController _templateQueryController =
      TextEditingController();
  final FocusNode _noteQueryFocusNode = FocusNode(debugLabel: 'note-search');
  final FocusNode _templateQueryFocusNode = FocusNode(
    debugLabel: 'template-search',
  );

  OrgTabId _tab = OrgTabId.home;
  String _noteQuery = '';
  String _templateQuery = '';
  String _categoryPath = kAllCategoryPath;
  String? _selectedNoteId;
  String? _selectedTemplateId;
  _DraftKind _draftKind = _DraftKind.none;
  String? _draftTemplateId;
  int _draftSerial = 0;

  @override
  void dispose() {
    _noteQueryController.dispose();
    _templateQueryController.dispose();
    _noteQueryFocusNode.dispose();
    _templateQueryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final snapshot = ref.watch(librarySnapshotProvider);
    final notes = _visibleNotes(snapshot);
    final templates = _visibleTemplates(snapshot);
    final activeNoteId = _activeNoteId(notes);
    final activeTemplateId = _activeTemplateId(templates);

    return Shortcuts(
      shortcuts: _desktopShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SelectTabIntent: CallbackAction<_SelectTabIntent>(
            onInvoke: (intent) {
              _selectTab(intent.tab);
              return null;
            },
          ),
          _StartDraftIntent: CallbackAction<_StartDraftIntent>(
            onInvoke: (_) {
              _startContextualDraft();
              return null;
            },
          ),
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _focusCurrentSearch();
              return null;
            },
          ),
          _DismissDraftIntent: CallbackAction<_DismissDraftIntent>(
            onInvoke: (_) {
              _dismissDraft();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: palette.bg,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final listWidth = _listPaneWidth(constraints.maxWidth);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SideRail(current: _tab, onSelect: _selectTab),
                      _Divider(color: palette.border),
                      SizedBox(
                        width: listWidth,
                        child: OrgDensity(
                          level: OrgDensityLevel.compact,
                          child: _buildListPane(
                            snapshot: snapshot,
                            notes: notes,
                            templates: templates,
                            activeNoteId: activeNoteId,
                            activeTemplateId: activeTemplateId,
                          ),
                        ),
                      ),
                      _Divider(color: palette.border),
                      Expanded(
                        child: OrgDensity(
                          level: OrgDensityLevel.comfortable,
                          child: _ContentPane(
                            tab: _tab,
                            draftKind: _draftKind,
                            draftTemplateId: _draftTemplateId,
                            draftSerial: _draftSerial,
                            activeNoteId: activeNoteId,
                            activeTemplate: _findTemplateById(
                              snapshot.templates,
                              activeTemplateId,
                            ),
                            templateNotes: _notesForTemplate(
                              snapshot.notes,
                              activeTemplateId,
                            ),
                            settings: widget.settings,
                            onDismissDraft: _dismissDraft,
                            onTemplateSaved: _finishTemplateDraft,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _listPaneWidth(double maxWidth) {
    if (maxWidth < 1080) return 280;
    if (maxWidth < 1280) return 304;
    return 328;
  }

  Widget _buildListPane({
    required LibrarySnapshot snapshot,
    required List<Note> notes,
    required List<Template> templates,
    required String? activeNoteId,
    required String? activeTemplateId,
  }) {
    return switch (_tab) {
      OrgTabId.home => _NotesListPane(
        notes: notes,
        allNotes: snapshot.notes,
        categories: snapshot.categories,
        templates: snapshot.templates,
        selectedNoteId: activeNoteId,
        selectedCategory: _categoryPath,
        queryController: _noteQueryController,
        queryFocusNode: _noteQueryFocusNode,
        onQueryChanged: (value) => setState(() => _noteQuery = value),
        onCategoryChanged: (value) => setState(() => _categoryPath = value),
        onCreate: () => _startDraft(_DraftKind.note),
        onSelect: (note) {
          setState(() {
            _selectedNoteId = note.id;
            _draftKind = _DraftKind.none;
          });
        },
        onTogglePinned: _togglePinned,
        onToggleFavorite: _toggleFavorite,
      ),
      OrgTabId.templates => _TemplatesListPane(
        templates: templates,
        notes: snapshot.notes,
        selectedTemplateId: activeTemplateId,
        queryController: _templateQueryController,
        queryFocusNode: _templateQueryFocusNode,
        onQueryChanged: (value) => setState(() => _templateQuery = value),
        onCreate: () => _startDraft(_DraftKind.template),
        onSelect: (template) {
          setState(() {
            _selectedTemplateId = template.id;
            _draftKind = _DraftKind.none;
          });
        },
      ),
      OrgTabId.settings => _SettingsListPane(snapshot: snapshot),
    };
  }

  void _selectTab(OrgTabId tab) {
    setState(() {
      _tab = tab;
      _draftKind = _DraftKind.none;
    });
  }

  void _startContextualDraft() {
    if (_tab == OrgTabId.templates) {
      _startDraft(_DraftKind.template);
      return;
    }
    _startDraft(_DraftKind.note);
  }

  void _focusCurrentSearch() {
    final target = _tab == OrgTabId.templates
        ? OrgTabId.templates
        : OrgTabId.home;
    setState(() {
      _tab = target;
      _draftKind = _DraftKind.none;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (target) {
        case OrgTabId.home:
          _noteQueryFocusNode.requestFocus();
        case OrgTabId.templates:
          _templateQueryFocusNode.requestFocus();
        case OrgTabId.settings:
          break;
      }
    });
  }

  void _dismissDraft() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_draftKind == _DraftKind.none) return;
    setState(() => _draftKind = _DraftKind.none);
  }

  void _finishTemplateDraft(Template template) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = OrgTabId.templates;
      _selectedTemplateId = template.id;
      _draftKind = _DraftKind.none;
    });
  }

  List<Note> _visibleNotes(LibrarySnapshot snapshot) {
    final search = NoteSearchState(query: _noteQuery, category: _categoryPath);
    final notes = search.apply(snapshot.notes).toList();
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return notes;
  }

  List<Template> _visibleTemplates(LibrarySnapshot snapshot) {
    final query = _templateQuery.trim().toLowerCase();
    final templates = snapshot.templates.where((template) {
      if (query.isEmpty) return true;
      if (template.name.toLowerCase().contains(query)) return true;
      return template.fields.any(
        (field) => field.label.toLowerCase().contains(query),
      );
    }).toList();
    templates.sort((a, b) {
      final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return templates;
  }

  String? _activeNoteId(List<Note> notes) {
    if (notes.any((note) => note.id == _selectedNoteId)) return _selectedNoteId;
    return notes.isEmpty ? null : notes.first.id;
  }

  String? _activeTemplateId(List<Template> templates) {
    if (templates.any((template) => template.id == _selectedTemplateId)) {
      return _selectedTemplateId;
    }
    return templates.isEmpty ? null : templates.first.id;
  }

  Template? _findTemplateById(List<Template> templates, String? id) {
    if (id == null) return null;
    for (final template in templates) {
      if (template.id == id) return template;
    }
    return null;
  }

  List<Note> _notesForTemplate(List<Note> notes, String? templateId) {
    if (templateId == null) return const <Note>[];
    final result = notes
        .where((note) => note.templateId == templateId)
        .toList();
    result.sort((a, b) {
      final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return result;
  }

  void _startDraft(_DraftKind kind, {String? templateId}) {
    setState(() {
      _draftKind = kind;
      _draftTemplateId = templateId;
      _draftSerial += 1;
      if (kind == _DraftKind.note) _tab = OrgTabId.home;
      if (kind == _DraftKind.template) _tab = OrgTabId.templates;
    });
  }

  Future<void> _togglePinned(Note note) async {
    await ref.read(noteRepositoryProvider).setPinned(note.id, !note.isPinned);
  }

  Future<void> _toggleFavorite(Note note) async {
    await ref
        .read(noteRepositoryProvider)
        .setFavorite(note.id, !note.isFavorite);
  }
}

class _ContentPane extends StatelessWidget {
  const _ContentPane({
    required this.tab,
    required this.draftKind,
    required this.draftTemplateId,
    required this.draftSerial,
    required this.activeNoteId,
    required this.activeTemplate,
    required this.templateNotes,
    required this.settings,
    required this.onDismissDraft,
    required this.onTemplateSaved,
  });

  final OrgTabId tab;
  final _DraftKind draftKind;
  final String? draftTemplateId;
  final int draftSerial;
  final String? activeNoteId;
  final Template? activeTemplate;
  final List<Note> templateNotes;
  final Widget settings;
  final VoidCallback onDismissDraft;
  final ValueChanged<Template> onTemplateSaved;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey(
      '${tab.name}:${draftKind.name}:$draftSerial:$activeNoteId:${activeTemplate?.id}',
    );
    return AnimatedSwitcher(
      duration: OrgDurations.page,
      switchInCurve: OrgCurves.easeOutQuint,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.015, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: key, child: _navigatorFor(context)),
    );
  }

  Widget _navigatorFor(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) {
        return PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => _rootFor(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      },
    );
  }

  Widget _rootFor(BuildContext context) {
    if (draftKind == _DraftKind.note) {
      return NoteEditorScreen(templateId: draftTemplateId);
    }
    if (draftKind == _DraftKind.template) {
      return TemplateBuilderScreen(
        onClose: onDismissDraft,
        onSaved: onTemplateSaved,
      );
    }
    return switch (tab) {
      OrgTabId.home =>
        activeNoteId == null
            ? const _ContentEmptyState(
                icon: Icons.note_add_rounded,
                title: 'No note selected',
                subtitle:
                    'Create a note or adjust the filters in the list pane.',
              )
            : NoteViewerScreen(noteId: activeNoteId!),
      OrgTabId.templates =>
        activeTemplate == null
            ? const _ContentEmptyState(
                icon: Icons.dashboard_customize_rounded,
                title: 'No template selected',
                subtitle:
                    'Create a template to start shaping structured notes.',
              )
            : _TemplateDetailPane(
                template: activeTemplate!,
                notes: templateNotes,
              ),
      OrgTabId.settings => settings,
    };
  }
}

class _NotesListPane extends StatelessWidget {
  const _NotesListPane({
    required this.notes,
    required this.allNotes,
    required this.categories,
    required this.templates,
    required this.selectedNoteId,
    required this.selectedCategory,
    required this.queryController,
    required this.queryFocusNode,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onCreate,
    required this.onSelect,
    required this.onTogglePinned,
    required this.onToggleFavorite,
  });

  final List<Note> notes;
  final List<Note> allNotes;
  final List<Category> categories;
  final List<Template> templates;
  final String? selectedNoteId;
  final String selectedCategory;
  final TextEditingController queryController;
  final FocusNode queryFocusNode;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onCreate;
  final ValueChanged<Note> onSelect;
  final ValueChanged<Note> onTogglePinned;
  final ValueChanged<Note> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return _ListPaneShell(
      title: 'Notes',
      subtitle: '${notes.length} visible / ${allNotes.length} total',
      icon: Icons.note_alt_rounded,
      actionIcon: Icons.add_rounded,
      actionTooltip: 'New note',
      onAction: onCreate,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _DenseSearchField(
              controller: queryController,
              focusNode: queryFocusNode,
              hint: 'Search notes',
              onChanged: onQueryChanged,
            ),
          ),
          _CategoryStrip(
            categories: categories,
            notes: allNotes,
            selected: selectedCategory,
            onSelect: onCategoryChanged,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: notes.isEmpty
                ? const _PaneEmpty(
                    message: 'No notes match',
                    subtitle: 'Try a different search or category.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return _DenseNoteRow(
                        note: note,
                        template: _findTemplate(templates, note.templateId),
                        category: _findCategory(categories, note.categoryPath),
                        selected: note.id == selectedNoteId,
                        onTap: () => onSelect(note),
                        onTogglePinned: () => onTogglePinned(note),
                        onToggleFavorite: () => onToggleFavorite(note),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Template? _findTemplate(List<Template> templates, String? id) {
    if (id == null) return null;
    for (final template in templates) {
      if (template.id == id) return template;
    }
    return null;
  }

  Category? _findCategory(List<Category> categories, String path) {
    if (path.isEmpty) return null;
    for (final category in categories) {
      if (category.path == path) return category;
    }
    return null;
  }
}

class _TemplatesListPane extends StatelessWidget {
  const _TemplatesListPane({
    required this.templates,
    required this.notes,
    required this.selectedTemplateId,
    required this.queryController,
    required this.queryFocusNode,
    required this.onQueryChanged,
    required this.onCreate,
    required this.onSelect,
  });

  final List<Template> templates;
  final List<Note> notes;
  final String? selectedTemplateId;
  final TextEditingController queryController;
  final FocusNode queryFocusNode;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCreate;
  final ValueChanged<Template> onSelect;

  @override
  Widget build(BuildContext context) {
    final fieldCount = templates.fold<int>(
      0,
      (sum, template) => sum + template.fields.length,
    );
    return _ListPaneShell(
      title: 'Schemas',
      subtitle: '${templates.length} templates / $fieldCount fields',
      icon: Icons.dashboard_customize_rounded,
      actionIcon: Icons.add_box_rounded,
      actionTooltip: 'New template',
      onAction: onCreate,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _DenseSearchField(
              controller: queryController,
              focusNode: queryFocusNode,
              hint: 'Search schemas',
              onChanged: onQueryChanged,
            ),
          ),
          Expanded(
            child: templates.isEmpty
                ? const _PaneEmpty(
                    message: 'No templates match',
                    subtitle: 'Create a schema or clear the search.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return _DenseTemplateRow(
                        template: template,
                        noteCount: notes
                            .where((note) => note.templateId == template.id)
                            .length,
                        selected: template.id == selectedTemplateId,
                        onTap: () => onSelect(template),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SettingsListPane extends StatelessWidget {
  const _SettingsListPane({required this.snapshot});

  final LibrarySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final sections = <_SettingsSummary>[
      _SettingsSummary(
        icon: Icons.sync_rounded,
        title: 'Sync',
        detail: snapshot.syncStatus.signedIn ? 'Google Drive ready' : 'Offline',
      ),
      _SettingsSummary(
        icon: Icons.palette_rounded,
        title: 'Customization',
        detail: 'Theme, accent, OLED',
      ),
      _SettingsSummary(
        icon: Icons.inventory_2_rounded,
        title: 'Data',
        detail:
            '${snapshot.notes.length} notes, ${snapshot.templates.length} templates',
      ),
      _SettingsSummary(
        icon: Icons.rule_rounded,
        title: 'Compliance',
        detail: '${snapshot.complianceSummary.activeCount} active issues',
      ),
      _SettingsSummary(
        icon: Icons.delete_outline_rounded,
        title: 'Trash',
        detail: '${snapshot.trash.length} items',
      ),
    ];
    return _ListPaneShell(
      title: 'Settings',
      subtitle: 'Workspace controls',
      icon: Icons.tune_rounded,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) =>
            _SettingsSummaryRow(summary: sections[index], selected: index == 0),
      ),
    );
  }
}

class _ListPaneShell extends StatelessWidget {
  const _ListPaneShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: palette.bgSecondary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: palette.accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actionIcon != null)
                  OrgIconButton(
                    icon: actionIcon!,
                    tooltip: actionTooltip ?? title,
                    size: 36,
                    onPressed: onAction,
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _DenseSearchField extends StatelessWidget {
  const _DenseSearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: palette.text,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: palette.textTertiary),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: palette.textTertiary,
            size: 18,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(
                    Icons.close_rounded,
                    color: palette.textTertiary,
                    size: 16,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: palette.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: palette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: palette.accent.withAlpha(150)),
          ),
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
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
    final chips = <Widget>[
      _CategoryPill(
        label: 'All',
        count: notes.length,
        active: selected == kAllCategoryPath,
        color: palette.accent,
        soft: palette.accentSoft,
        onTap: () => onSelect(kAllCategoryPath),
      ),
      for (final category in categories)
        _CategoryPill(
          label: category.name,
          count: notes
              .where((note) => note.categoryPath == category.path)
              .length,
          active: selected == category.path,
          color: accentForHue(
            hueOfCategory(category, fallbackHue: palette.accentHue),
          ),
          soft: softForHue(
            hueOfCategory(category, fallbackHue: palette.accentHue),
            0.18,
          ),
          onTap: () => onSelect(category.path),
        ),
    ];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) => chips[index],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.count,
    required this.active,
    required this.color,
    required this.soft,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final Color color;
  final Color soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: OrgDurations.toggle,
        curve: OrgCurves.spring,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? soft : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? color.withAlpha(140) : palette.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? color : palette.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: active ? color : palette.textTertiary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DenseNoteRow extends StatefulWidget {
  const _DenseNoteRow({
    required this.note,
    required this.template,
    required this.category,
    required this.selected,
    required this.onTap,
    required this.onTogglePinned,
    required this.onToggleFavorite,
  });

  final Note note;
  final Template? template;
  final Category? category;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleFavorite;

  @override
  State<_DenseNoteRow> createState() => _DenseNoteRowState();
}

class _DenseNoteRowState extends State<_DenseNoteRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final hue = widget.category == null
        ? palette.accentHue
        : hueOfCategory(widget.category!, fallbackHue: palette.accentHue);
    final accent = accentForHue(hue);
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: OrgDurations.hover,
            curve: OrgCurves.easeOutQuint,
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? palette.accentSoft
                  : _hover
                  ? palette.surface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? palette.accent.withAlpha(110)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: softForHue(hue, selected ? 0.28 : 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.note.icon ?? _initialFor(widget.note.title),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.note.title.isEmpty
                                  ? 'Untitled note'
                                  : widget.note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: palette.text,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.template?.name ?? 'No template'} / ${formatRelativeTime(widget.note.updatedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _MiniIconButton(
                  icon: widget.note.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  tooltip: widget.note.isPinned ? 'Unpin' : 'Pin',
                  active: widget.note.isPinned,
                  onTap: widget.onTogglePinned,
                ),
                _MiniIconButton(
                  icon: widget.note.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  tooltip: widget.note.isFavorite ? 'Unfavorite' : 'Favorite',
                  active: widget.note.isFavorite,
                  onTap: widget.onToggleFavorite,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DenseTemplateRow extends StatefulWidget {
  const _DenseTemplateRow({
    required this.template,
    required this.noteCount,
    required this.selected,
    required this.onTap,
  });

  final Template template;
  final int noteCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DenseTemplateRow> createState() => _DenseTemplateRowState();
}

class _DenseTemplateRowState extends State<_DenseTemplateRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: OrgDurations.hover,
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? palette.accentSoft
                  : _hover
                  ? palette.surface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? palette.accent.withAlpha(110)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: palette.surfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.template.icon ?? _initialFor(widget.template.name),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.template.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.template.fields.length} fields / ${widget.noteCount} notes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _LayoutBadge(layout: widget.template.layout),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: 18,
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 34,
          child: Icon(
            icon,
            size: 15,
            color: active ? palette.accent : palette.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _SettingsSummary {
  const _SettingsSummary({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;
}

class _SettingsSummaryRow extends StatelessWidget {
  const _SettingsSummaryRow({required this.summary, required this.selected});

  final _SettingsSummary summary;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? palette.accentSoft : palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? palette.accent.withAlpha(110) : palette.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            summary.icon,
            color: selected ? palette.accent : palette.textSecondary,
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateDetailPane extends StatelessWidget {
  const _TemplateDetailPane({required this.template, required this.notes});

  final Template template;
  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final requiredCount = template.fields
        .where((field) => field.isRequired)
        .length;
    return Scaffold(
      backgroundColor: palette.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: palette.accentSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: palette.borderStrong),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          template.icon ?? _initialFor(template.name),
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: palette.text,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _InfoPill(
                                  icon: Icons.view_agenda_rounded,
                                  label: template.layout.name,
                                ),
                                _InfoPill(
                                  icon: Icons.layers_rounded,
                                  label:
                                      '${template.fields.length} fields, $requiredCount required',
                                ),
                                _InfoPill(
                                  icon: Icons.note_alt_rounded,
                                  label:
                                      '${notes.length} note${notes.length == 1 ? '' : 's'}',
                                ),
                                if (template.updatedAt != null)
                                  _InfoPill(
                                    icon: Icons.update_rounded,
                                    label: formatRelativeTime(
                                      template.updatedAt,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OrgIconButton(
                        icon: Icons.edit_rounded,
                        tooltip: 'Edit template',
                        onPressed: () => Navigator.of(context).push(
                          OrgOverlayRoute<void>(
                            builder: (_) =>
                                TemplateBuilderScreen(templateId: template.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          OrgOverlayRoute<void>(
                            builder: (_) =>
                                NoteEditorScreen(templateId: template.id),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create note'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          OrgOverlayRoute<void>(
                            builder: (_) =>
                                TemplateBuilderScreen(templateId: template.id),
                          ),
                        ),
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Edit schema'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            sliver: SliverToBoxAdapter(
              child: _DetailSectionTitle(
                title: 'Fields',
                subtitle:
                    '${template.fields.length} captured values per record',
              ),
            ),
          ),
          if (template.fields.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: _PaneEmpty(
                  message: 'No fields yet',
                  subtitle: 'Edit the schema to add structured inputs.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              sliver: SliverList.separated(
                itemCount: template.fields.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final field = template.fields[index];
                  return _FieldSummaryRow(index: index, field: field);
                },
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            sliver: SliverToBoxAdapter(
              child: _DetailSectionTitle(
                title: 'Associated notes',
                subtitle: notes.isEmpty
                    ? 'No notes use this template yet'
                    : '${notes.length} sorted by recent changes',
              ),
            ),
          ),
          if (notes.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: _PaneEmpty(
                  message: 'Unused schema',
                  subtitle: 'Create a note from this template when ready.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
              sliver: SliverList.separated(
                itemCount: notes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return _AssociatedNoteTile(
                    note: note,
                    onTap: () => Navigator.of(context).push(
                      OrgOverlayRoute<void>(
                        builder: (_) => NoteViewerScreen(noteId: note.id),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailSectionTitle extends StatelessWidget {
  const _DetailSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldSummaryRow extends StatelessWidget {
  const _FieldSummaryRow({required this.index, required this.field});

  final int index;
  final TemplateField field;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: palette.accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  field.hint?.isNotEmpty == true
                      ? field.hint!
                      : field.type.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _InfoPill(
            icon: _iconForField(field.type),
            label: field.isRequired
                ? '${field.type.name} / required'
                : field.type.name,
          ),
        ],
      ),
    );
  }

  IconData _iconForField(TemplateFieldType type) {
    return switch (type) {
      TemplateFieldType.text => Icons.notes_rounded,
      TemplateFieldType.number => Icons.pin_rounded,
      TemplateFieldType.date => Icons.calendar_month_rounded,
      TemplateFieldType.boolean => Icons.toggle_on_rounded,
      TemplateFieldType.dropdown => Icons.arrow_drop_down_circle_rounded,
      TemplateFieldType.password => Icons.password_rounded,
      TemplateFieldType.url => Icons.link_rounded,
      TemplateFieldType.ip => Icons.dns_rounded,
      TemplateFieldType.regex => Icons.rule_rounded,
      TemplateFieldType.image => Icons.image_rounded,
      TemplateFieldType.customLabel => Icons.label_rounded,
    };
  }
}

class _AssociatedNoteTile extends StatelessWidget {
  const _AssociatedNoteTile({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Text(
              note.icon ?? _initialFor(note.title),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${note.records.length} records / ${formatRelativeTime(note.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: palette.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutBadge extends StatelessWidget {
  const _LayoutBadge({required this.layout});

  final TemplateLayout layout;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final icon = switch (layout) {
      TemplateLayout.cards => Icons.view_agenda_rounded,
      TemplateLayout.table => Icons.table_rows_rounded,
      TemplateLayout.grid => Icons.grid_view_rounded,
    };
    return Tooltip(
      message: layout.name,
      child: Icon(icon, size: 16, color: palette.textTertiary),
    );
  }
}

class _PaneEmpty extends StatelessWidget {
  const _PaneEmpty({required this.message, required this.subtitle});

  final String message;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, color: palette.textTertiary, size: 24),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ContentEmptyState extends StatelessWidget {
  const _ContentEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Scaffold(
      backgroundColor: palette.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: palette.accent, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideRail extends ConsumerWidget {
  const _SideRail({required this.current, required this.onSelect});

  final OrgTabId current;
  final ValueChanged<OrgTabId> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = OrgPaletteScope.of(context);
    const items = <_RailItem>[
      _RailItem(
        id: OrgTabId.home,
        icon: Icons.home_rounded,
        label: 'Home',
        shortcutLabel: 'Ctrl/Cmd+1',
      ),
      _RailItem(
        id: OrgTabId.templates,
        icon: Icons.dashboard_customize_rounded,
        label: 'Templates',
        shortcutLabel: 'Ctrl/Cmd+2',
      ),
      _RailItem(
        id: OrgTabId.settings,
        icon: Icons.tune_rounded,
        label: 'Settings',
        shortcutLabel: 'Ctrl/Cmd+3',
      ),
    ];
    final theme = ref.watch(themeProvider);
    final isLight = theme.themePreference == ThemePreference.light;
    return Container(
      width: 64,
      color: palette.bgSecondary,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: RotatedBox(quarterTurns: 3, child: Wordmark(size: 16)),
          ),
          for (final item in items)
            _RailButton(
              item: item,
              active: current == item.id,
              onTap: () => onSelect(item.id),
            ),
          const Spacer(),
          _RailIconButton(
            icon: isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            label: isLight ? 'Dark mode' : 'Light mode',
            onTap: () {
              ref
                  .read(themeProvider.notifier)
                  .setThemePreference(
                    isLight ? ThemePreference.dark : ThemePreference.light,
                  );
            },
          ),
          const SizedBox(height: 6),
          _RailIconButton(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            onTap: () => onSelect(OrgTabId.settings),
          ),
        ],
      ),
    );
  }
}

class _RailItem {
  const _RailItem({
    required this.id,
    required this.icon,
    required this.label,
    this.shortcutLabel,
  });

  final OrgTabId id;
  final IconData icon;
  final String label;
  final String? shortcutLabel;
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _RailItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RailIconButton(
      icon: item.icon,
      label: item.label,
      shortcutLabel: item.shortcutLabel,
      active: active,
      onTap: onTap,
    );
  }
}

class _RailIconButton extends StatefulWidget {
  const _RailIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.shortcutLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final String? shortcutLabel;

  @override
  State<_RailIconButton> createState() => _RailIconButtonState();
}

class _RailIconButtonState extends State<_RailIconButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final color = widget.active ? palette.accent : palette.textTertiary;
    final tooltip = widget.shortcutLabel == null
        ? widget.label
        : '${widget.label} - ${widget.shortcutLabel}';
    final scale = _down
        ? 0.94
        : _hover
        ? 1.03
        : 1.0;
    final background = widget.active
        ? palette.accentSoft
        : _hover
        ? palette.surfaceHigh
        : Colors.transparent;
    return Semantics(
      label: widget.label,
      hint: widget.shortcutLabel == null
          ? null
          : 'Keyboard shortcut ${widget.shortcutLabel}',
      button: true,
      selected: widget.active,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() {
            _hover = false;
            _down = false;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: InkResponse(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _down = true),
              onTapCancel: () => setState(() => _down = false),
              onTapUp: (_) => setState(() => _down = false),
              radius: 32,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedScale(
                scale: scale,
                duration: OrgDurations.tap,
                curve: OrgCurves.spring,
                child: AnimatedContainer(
                  duration: OrgDurations.toggle,
                  curve: OrgCurves.spring,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _hover && !widget.active
                          ? palette.border
                          : Colors.transparent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(widget.icon, color: color, size: 22),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: color);
  }
}

String _initialFor(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}
