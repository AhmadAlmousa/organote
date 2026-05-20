import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/models.dart';
import '../../../domain/repositories/repositories.dart';
import '../../theme/color_tokens.dart';
import '../org_toast.dart';
import 'form_field_host.dart';

class ImageFieldImpl extends StatefulWidget {
  const ImageFieldImpl({
    super.key,
    required this.field,
    required this.controller,
    required this.assetRepository,
    required this.ensureNoteId,
    required this.onChanged,
    this.error,
    this.accent,
  });

  final TemplateField field;
  final TextEditingController controller;
  final AssetRepository assetRepository;
  final Future<String?> Function() ensureNoteId;
  final VoidCallback onChanged;
  final String? error;
  final Color? accent;

  @override
  State<ImageFieldImpl> createState() => _ImageFieldImplState();
}

class _ImageFieldImplState extends State<ImageFieldImpl> {
  bool _picking = false;
  String? _previewPath;
  Future<Uint8List>? _previewFuture;

  Future<void> _pickImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final noteId = await widget.ensureNoteId();
      if (!mounted) return;
      if (noteId == null) {
        _showFailure('Add a title before importing images');
        return;
      }
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showFailure('Could not read selected image');
        return;
      }
      final asset = await widget.assetRepository.importImageForNote(
        noteId: noteId,
        originalName: file.name,
        bytes: bytes,
        mediaType: _mediaTypeFor(file.name),
      );
      if (!mounted) return;
      widget.controller.text = asset.relativePath;
      widget.onChanged();
      setState(() {
        _previewPath = null;
        _previewFuture = null;
      });
      showOrgToast(
        context,
        message: 'Image imported',
        icon: Icons.image_rounded,
        background: widget.accent,
      );
    } catch (_) {
      if (!mounted) return;
      _showFailure('Image import failed');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged();
    setState(() {
      _previewPath = null;
      _previewFuture = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final accent = widget.accent ?? palette.accent;
    return FormFieldHost(
      label: widget.field.label,
      required: widget.field.isRequired,
      accent: widget.accent,
      error: widget.error,
      hint: widget.field.hint ?? 'Imported images are stored under assets/',
      contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          final path = value.text.trim();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ImagePreview(
                path: path,
                future: _futureFor(path),
                palette: palette,
                accent: accent,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _picking ? null : _pickImage,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: palette.onAccent,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(
                      _picking
                          ? Icons.hourglass_top_rounded
                          : Icons.add_photo_alternate_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _picking ? 'Importing' : 'Import image',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  if (path.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clear,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.textSecondary,
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: const Text(
                        'Clear',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
              ),
              if (path.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textTertiary,
                    fontFamily: 'JetBrainsMono',
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<Uint8List>? _futureFor(String path) {
    if (path.isEmpty) return null;
    if (_previewPath != path) {
      _previewPath = path;
      _previewFuture = widget.assetRepository.readAssetBytes(path);
    }
    return _previewFuture;
  }

  void _showFailure(String message) {
    final palette = OrgPaletteScope.of(context);
    showOrgToast(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      background: palette.danger,
      foreground: palette.onAccent,
    );
  }

  String? _mediaTypeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return null;
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.path,
    required this.future,
    required this.palette,
    required this.accent,
  });

  final String path;
  final Future<Uint8List>? future;
  final OrgPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty || future == null) {
      return _PreviewFrame(
        palette: palette,
        child: Icon(
          Icons.image_outlined,
          color: palette.textTertiary,
          size: 24,
        ),
      );
    }
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _PreviewFrame(
            palette: palette,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _PreviewFrame(
            palette: palette,
            child: Icon(
              Icons.broken_image_outlined,
              color: palette.danger,
              size: 24,
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.palette, required this.child});

  final OrgPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
