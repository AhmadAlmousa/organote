import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../state/app_providers.dart';
import '../../theme/color_tokens.dart';
import '../../theme/density.dart';
import '../../theme/motion.dart';
import '../../widgets/org_empty_state.dart';
import '../../widgets/org_icon_button.dart';
import '../../widgets/org_toast.dart';

enum _RawSaveStatus { loading, clean, dirty, saving, saved, error }

enum _RawViewMode { editor, preview, split }

class RawSourceEditorScreen extends ConsumerStatefulWidget {
  const RawSourceEditorScreen({
    super.key,
    required this.noteId,
    required this.noteTitle,
  });

  final String noteId;
  final String noteTitle;

  @override
  ConsumerState<RawSourceEditorScreen> createState() =>
      _RawSourceEditorScreenState();
}

class _RawSourceEditorScreenState extends ConsumerState<RawSourceEditorScreen> {
  static const Duration _autosaveDelay = Duration(seconds: 2);

  final TextEditingController _sourceController = TextEditingController();
  final FocusNode _sourceFocus = FocusNode();

  _RawSaveStatus _status = _RawSaveStatus.loading;
  _RawViewMode _mode = _RawViewMode.split;
  Timer? _autosave;
  bool _saving = false;
  bool _queuedSave = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSource();
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _sourceController.dispose();
    _sourceFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSource() async {
    setState(() {
      _status = _RawSaveStatus.loading;
      _errorMessage = null;
    });
    try {
      final source = await ref
          .read(noteRepositoryProvider)
          .getRawSource(widget.noteId);
      if (!mounted) return;
      _sourceController.text = source;
      setState(() => _status = _RawSaveStatus.clean);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _status = _RawSaveStatus.error;
        _errorMessage = err.toString();
      });
    }
  }

  void _touch() {
    if (_status == _RawSaveStatus.loading) return;
    _autosave?.cancel();
    if (!_saving) {
      setState(() {
        _status = _RawSaveStatus.dirty;
        _errorMessage = null;
      });
    } else {
      _queuedSave = true;
    }
    _autosave = Timer(_autosaveDelay, _save);
  }

  Future<void> _save() async {
    if (_status != _RawSaveStatus.dirty && !_queuedSave) return;
    if (_saving) {
      _queuedSave = true;
      return;
    }
    _autosave?.cancel();
    _saving = true;
    _queuedSave = false;
    final source = _sourceController.text;
    setState(() {
      _status = _RawSaveStatus.saving;
      _errorMessage = null;
    });
    try {
      await ref
          .read(noteRepositoryProvider)
          .saveRawSource(widget.noteId, source);
      if (!mounted) return;
      setState(() {
        _status = _sourceController.text == source
            ? _RawSaveStatus.saved
            : _RawSaveStatus.dirty;
        _errorMessage = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _status = _RawSaveStatus.error;
        _errorMessage = err.toString();
      });
    } finally {
      _saving = false;
    }
    if (mounted && _queuedSave) {
      await _save();
    }
  }

  Future<void> _saveNow() async {
    if (_status == _RawSaveStatus.loading || _status == _RawSaveStatus.saving) {
      return;
    }
    if (_status == _RawSaveStatus.error) {
      setState(() => _status = _RawSaveStatus.dirty);
    }
    await _save();
    if (!mounted) return;
    if (_status == _RawSaveStatus.saved) {
      showOrgToast(
        context,
        message: 'Raw source saved',
        icon: Icons.check_rounded,
      );
    }
  }

  Future<void> _flushAndPop() async {
    _autosave?.cancel();
    if (_status == _RawSaveStatus.error && _sourceController.text.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    if (_status == _RawSaveStatus.dirty || _status == _RawSaveStatus.error) {
      await _save();
    }
    while (_saving) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    if (!mounted || _status == _RawSaveStatus.error) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _flushAndPop();
      },
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              const _SaveIntent(),
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
              const _SaveIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _SaveIntent: CallbackAction<_SaveIntent>(
              onInvoke: (_) {
                unawaited(_saveNow());
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: palette.bg,
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _RawEditorHeader(
                      title: widget.noteTitle,
                      status: _status,
                      mode: _mode,
                      onModeChanged: (mode) => setState(() => _mode = mode),
                      onBack: _flushAndPop,
                      onSave: _saveNow,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: OrgDurations.page,
                        switchInCurve: OrgCurves.sheet,
                        child: _buildBody(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    if (_status == _RawSaveStatus.loading) {
      return Center(
        key: const ValueKey('raw-loading'),
        child: CircularProgressIndicator(color: palette.accent),
      );
    }
    if (_status == _RawSaveStatus.error && _sourceController.text.isEmpty) {
      return OrgEmptyState(
        key: const ValueKey('raw-error'),
        emoji: '!',
        message: 'Raw source unavailable',
        subtitle: _errorMessage ?? 'Try again from the note viewer.',
        action: OutlinedButton.icon(
          onPressed: _loadSource,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
        ),
      );
    }

    return LayoutBuilder(
      key: ValueKey('raw-${_mode.name}'),
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final source = _SourcePane(
          controller: _sourceController,
          focusNode: _sourceFocus,
          onChanged: _touch,
        );
        final preview = _PreviewPane(source: _sourceController.text);

        if (_mode == _RawViewMode.editor) return source;
        if (_mode == _RawViewMode.preview) return preview;
        if (wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: source),
                const SizedBox(width: 12),
                Expanded(child: preview),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
          child: Column(
            children: [
              Expanded(child: source),
              const SizedBox(height: 10),
              Expanded(child: preview),
            ],
          ),
        );
      },
    );
  }
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _RawEditorHeader extends StatelessWidget {
  const _RawEditorHeader({
    required this.title,
    required this.status,
    required this.mode,
    required this.onModeChanged,
    required this.onBack,
    required this.onSave,
  });

  final String title;
  final _RawSaveStatus status;
  final _RawViewMode mode;
  final ValueChanged<_RawViewMode> onModeChanged;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final compact = OrgDensity.of(context) == OrgDensityLevel.compact;
    final horizontal = compact ? 10.0 : 14.0;
    final saving =
        status == _RawSaveStatus.saving || status == _RawSaveStatus.loading;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 6),
      child: Column(
        children: [
          Row(
            children: [
              OrgIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: onBack,
                tooltip: 'Back',
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raw source',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title.isEmpty ? 'Untitled note' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RawStatusBadge(status: status),
              const SizedBox(width: 8),
              OrgIconButton(
                icon: Icons.save_outlined,
                onPressed: saving ? null : onSave,
                tooltip: 'Save',
                size: 38,
                foreground: saving ? palette.textTertiary : palette.text,
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onBack,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _RawModeTabs(mode: mode, onChanged: onModeChanged),
        ],
      ),
    );
  }
}

class _RawStatusBadge extends StatelessWidget {
  const _RawStatusBadge({required this.status});

  final _RawSaveStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final (icon, label, color) = switch (status) {
      _RawSaveStatus.loading => (
        Icons.hourglass_top_rounded,
        'Loading',
        palette.textSecondary,
      ),
      _RawSaveStatus.clean => (Icons.check_rounded, 'Ready', palette.success),
      _RawSaveStatus.dirty => (
        Icons.timelapse_rounded,
        'Autosaving',
        palette.accent,
      ),
      _RawSaveStatus.saving => (
        Icons.cloud_upload_outlined,
        'Saving',
        palette.accent,
      ),
      _RawSaveStatus.saved => (Icons.check_rounded, 'Saved', palette.success),
      _RawSaveStatus.error => (
        Icons.error_outline_rounded,
        'Save failed',
        palette.danger,
      ),
    };
    return AnimatedContainer(
      duration: OrgDurations.toggle,
      curve: OrgCurves.spring,
      padding: const EdgeInsetsDirectional.fromSTEB(9, 6, 10, 6),
      decoration: BoxDecoration(
        color: color.withAlpha(34),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RawModeTabs extends StatelessWidget {
  const _RawModeTabs({required this.mode, required this.onChanged});

  final _RawViewMode mode;
  final ValueChanged<_RawViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: 'Editor',
            icon: Icons.edit_note_rounded,
            selected: mode == _RawViewMode.editor,
            onTap: () => onChanged(_RawViewMode.editor),
          ),
          _ModeButton(
            label: 'Preview',
            icon: Icons.article_outlined,
            selected: mode == _RawViewMode.preview,
            onTap: () => onChanged(_RawViewMode.preview),
          ),
          _ModeButton(
            label: 'Split',
            icon: Icons.splitscreen_rounded,
            selected: mode == _RawViewMode.split,
            onTap: () => onChanged(_RawViewMode.split),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final color = selected ? palette.onAccent : palette.textSecondary;
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: OrgDurations.toggle,
            curve: OrgCurves.spring,
            decoration: BoxDecoration(
              color: selected ? palette.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourcePane extends StatelessWidget {
  const _SourcePane({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final source = controller.text;
    final lines = source.isEmpty ? 1 : '\n'.allMatches(source).length + 1;
    return _RawPanel(
      title: 'Markdown source',
      meta: '$lines lines',
      icon: Icons.code_rounded,
      child: TextField(
        key: const Key('raw-source-editor-field'),
        controller: controller,
        focusNode: focusNode,
        onChanged: (_) => onChanged(),
        cursorColor: OrgPaletteScope.of(context).accent,
        expands: true,
        maxLines: null,
        minLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        autocorrect: false,
        enableSuggestions: false,
        style: TextStyle(
          color: OrgPaletteScope.of(context).text,
          fontFamily: 'JetBrainsMono',
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
          height: 1.55,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: '# Untitled note',
          hintStyle: TextStyle(
            color: OrgPaletteScope.of(context).textTertiary,
            fontFamily: 'JetBrainsMono',
            fontSize: 13.5,
            letterSpacing: 0,
          ),
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final chars = source.characters.length;
    return _RawPanel(
      title: 'Rendered preview',
      meta: '$chars chars',
      icon: Icons.article_outlined,
      child: source.trim().isEmpty
          ? Center(
              child: Text(
                'Nothing to preview',
                style: TextStyle(
                  color: palette.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : SingleChildScrollView(
              key: const Key('raw-source-preview'),
              physics: const BouncingScrollPhysics(),
              child: GptMarkdownTheme(
                gptThemeData: GptMarkdownThemeData(
                  brightness: palette.brightness,
                  highlightColor: palette.accentSoft,
                  h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                  h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                  h3: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                  hrLineColor: palette.borderStrong,
                  hrLinePadding: const EdgeInsets.symmetric(vertical: 10),
                  linkColor: palette.accent,
                  linkHoverColor: palette.accentDeep,
                  autoAddDividerLineAfterH1: false,
                ),
                child: GptMarkdown(
                  source,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    height: 1.5,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
    );
  }
}

class _RawPanel extends StatelessWidget {
  const _RawPanel({
    required this.title,
    required this.meta,
    required this.icon,
    required this.child,
  });

  final String title;
  final String meta;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadowSoft,
            blurRadius: 28,
            spreadRadius: -18,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: palette.accent, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Text(
                  meta,
                  style: TextStyle(
                    color: palette.textTertiary,
                    fontFamily: 'JetBrainsMono',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: palette.border),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(14), child: child),
          ),
        ],
      ),
    );
  }
}
