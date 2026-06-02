import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../services/storage/file_store.dart';
import '../state/app_providers.dart';
import '../theme/color_tokens.dart';
import '../theme/motion.dart';
import '../widgets/wordmark.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, required this.onReady});

  final VoidCallback onReady;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

enum _SplashPhase { initializing, needsStorage, ready, errored }

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  _SplashPhase _phase = _SplashPhase.initializing;
  StorageUnavailableReason? _storageReason;
  String? _message;
  bool _choosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final fileStore = ref.read(fileStoreProvider);
    final library = ref.read(libraryRepositoryProvider);
    final status = await fileStore.getStatus();
    if (!status.isAvailable) {
      if (!mounted) return;
      setState(() {
        _phase = _SplashPhase.needsStorage;
        _storageReason = status.reason;
        _message = status.message;
      });
      return;
    }
    try {
      await library.reload();
      if (!mounted) return;
      setState(() => _phase = _SplashPhase.ready);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      widget.onReady();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _SplashPhase.errored;
        _storageReason = null;
        _message = error.toString();
      });
    }
  }

  Future<void> _chooseStorage() async {
    if (_storageReason == StorageUnavailableReason.unsupportedPlatform) return;
    final fileStore = ref.read(fileStoreProvider);
    setState(() {
      _choosing = true;
      _message = null;
    });
    try {
      await fileStore.chooseRootDirectory();
      if (!mounted) return;
      setState(() {
        _phase = _SplashPhase.initializing;
        _storageReason = null;
        _message = null;
        _choosing = false;
      });
      await _bootstrap();
    } on StorageUnavailableException catch (error) {
      if (!mounted) return;
      setState(() {
        _storageReason = error.reason;
        _message = error.message;
        _choosing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not open folder: $error';
        _choosing = false;
      });
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _bob,
                    builder: (context, child) {
                      final value = Curves.easeInOut.transform(_bob.value);
                      return Transform.translate(
                        offset: Offset(0, -6 * value),
                        child: child,
                      );
                    },
                    child: const Wordmark(size: 30),
                  ),
                  const SizedBox(height: 26),
                  AnimatedSwitcher(
                    duration: OrgDurations.overlay,
                    switchInCurve: OrgCurves.sheet,
                    child: _buildPhase(context, palette),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase(BuildContext context, OrgPalette palette) {
    switch (_phase) {
      case _SplashPhase.initializing:
        return Column(
          key: const ValueKey('initializing'),
          children: [
            LoadingAnimationWidget.staggeredDotsWave(
              color: palette.accent,
              size: 36,
            ),
            const SizedBox(height: 14),
            Text(
              'Preparing your library…',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
            ),
          ],
        );
      case _SplashPhase.needsStorage:
        final unsupported =
            _storageReason == StorageUnavailableReason.unsupportedPlatform;
        final reconnect =
            _storageReason == StorageUnavailableReason.permissionDenied;
        return Column(
          key: const ValueKey('needs-storage'),
          children: [
            if (unsupported) ...[
              Icon(
                Icons.desktop_windows_rounded,
                color: palette.warning,
                size: 34,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              unsupported
                  ? 'Desktop browser required'
                  : reconnect
                  ? 'Reconnect your Organote folder'
                  : kIsWeb
                  ? 'Choose a folder for your Organote library'
                  : 'Pick a storage folder',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: palette.text),
            ),
            const SizedBox(height: 8),
            Text(
              _message ??
                  (kIsWeb
                      ? 'Organote stores notes as real markdown files in a folder you choose.'
                      : 'Pick where notes, templates, and assets should live on disk.'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 18),
            if (unsupported)
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.block_rounded, size: 18),
                label: const Text('Folder picker unavailable'),
              )
            else
              FilledButton.icon(
                onPressed: _choosing ? null : _chooseStorage,
                icon: _choosing
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.onAccent,
                        ),
                      )
                    : const Icon(Icons.folder_open_rounded, size: 18),
                label: Text(
                  _choosing
                      ? 'Opening picker...'
                      : reconnect
                      ? 'Reconnect folder'
                      : 'Choose folder',
                ),
              ),
          ],
        );
      case _SplashPhase.ready:
        return Column(
          key: const ValueKey('ready'),
          children: [
            Icon(Icons.check_rounded, color: palette.accent, size: 36),
            const SizedBox(height: 8),
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      case _SplashPhase.errored:
        return Column(
          key: const ValueKey('errored'),
          children: [
            Icon(Icons.error_outline_rounded, color: palette.danger, size: 32),
            const SizedBox(height: 8),
            Text(
              'Something broke during init',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 6),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _phase = _SplashPhase.initializing;
                  _storageReason = null;
                  _message = null;
                });
                _bootstrap();
              },
              child: const Text('Retry'),
            ),
          ],
        );
    }
  }
}
