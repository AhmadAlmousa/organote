import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../domain/models/models.dart';
import '../../../services/storage/file_store.dart';
import '../../app/overlay_route.dart';
import '../../state/app_providers.dart';
import '../../state/library_provider.dart';
import '../../theme/color_tokens.dart';
import '../../theme/density.dart';
import '../../theme/motion.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/org_icon_button.dart';
import '../../widgets/org_toast.dart';
import 'phase9_screens.dart';

final _settingsStorageStatusProvider = FutureProvider<StorageStatus>((ref) {
  return ref.watch(fileStoreProvider).getStatus();
});

final _settingsSyncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.watch(syncRepositoryProvider).watchSyncStatus();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _storageBusy = false;
  bool _syncBusy = false;
  bool _scanBusy = false;
  bool _errorLogBusy = false;

  Future<void> _chooseStorageRoot() async {
    if (_storageBusy) return;
    setState(() => _storageBusy = true);
    try {
      final store = ref.read(fileStoreProvider);
      await store.chooseRootDirectory();
      await store.ensureStructure();
      ref.invalidate(_settingsStorageStatusProvider);
      await ref.read(libraryRepositoryProvider).reload();
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Storage updated',
        icon: Icons.folder_rounded,
      );
    } catch (error, stackTrace) {
      await ref
          .read(errorLogServiceProvider)
          .recordError(error, stackTrace, source: 'settings.chooseStorageRoot');
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Storage update failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _storageBusy = false);
    }
  }

  Future<void> _connectDrive() async {
    if (_syncBusy) return;
    setState(() => _syncBusy = true);
    try {
      await ref.read(syncRepositoryProvider).signInGoogleDrive();
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Drive connected',
        icon: Icons.cloud_done_rounded,
      );
    } catch (error, stackTrace) {
      await ref
          .read(errorLogServiceProvider)
          .recordError(error, stackTrace, source: 'settings.connectDrive');
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Drive connection failed: ${_compactError(error)}',
        icon: Icons.cloud_off_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  Future<void> _syncNow() async {
    if (_syncBusy) return;
    setState(() => _syncBusy = true);
    try {
      await ref.read(syncRepositoryProvider).syncNow();
      if (!mounted) return;
      showOrgToast(context, message: 'Sync complete', icon: Icons.sync_rounded);
    } catch (error, stackTrace) {
      await ref
          .read(errorLogServiceProvider)
          .recordError(error, stackTrace, source: 'settings.syncNow');
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Sync failed',
        icon: Icons.sync_problem_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  Future<void> _scanCompliance() async {
    if (_scanBusy) return;
    setState(() => _scanBusy = true);
    try {
      await ref.read(complianceRepositoryProvider).scanNow();
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Compliance scanned',
        icon: Icons.fact_check_rounded,
      );
    } catch (error, stackTrace) {
      await ref
          .read(errorLogServiceProvider)
          .recordError(error, stackTrace, source: 'settings.scanCompliance');
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Scan failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _scanBusy = false);
    }
  }

  Future<void> _setErrorLogging(bool value) async {
    if (_errorLogBusy) return;
    setState(() => _errorLogBusy = true);
    try {
      await ref.read(errorLogServiceProvider).setEnabled(value);
      if (!mounted) return;
      showOrgToast(
        context,
        message: value ? 'Error log enabled' : 'Error log disabled',
        icon: value ? Icons.receipt_long_rounded : Icons.receipt_rounded,
      );
    } catch (error, stackTrace) {
      await ref
          .read(errorLogServiceProvider)
          .recordError(error, stackTrace, source: 'settings.errorLogToggle');
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Error log setting failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _errorLogBusy = false);
    }
  }

  void _openComplianceReview() {
    Navigator.of(context).push(
      OrgOverlayRoute<void>(builder: (_) => const ComplianceReviewScreen()),
    );
  }

  void _openTrash() {
    final route = OrgOverlayRoute<void>(builder: (_) => const TrashScreen());
    Navigator.of(context).push(route);
  }

  void _openBackupRestore() {
    final route = OrgOverlayRoute<void>(
      builder: (_) => const BackupRestoreScreen(),
    );
    Navigator.of(context).push(route);
  }

  void _openDangerZone() {
    final route = OrgOverlayRoute<void>(
      builder: (_) => const DangerZoneScreen(),
    );
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final snapshot = ref.watch(librarySnapshotProvider);
    final theme = ref.watch(themeProvider);
    final storage = ref.watch(_settingsStorageStatusProvider);
    final errorLogService = ref.watch(errorLogServiceProvider);
    final errorLogEnabled = errorLogService.isEnabled;
    final syncStream = ref.watch(_settingsSyncStatusProvider);
    final syncStatus = syncStream.maybeWhen(
      data: (status) => status,
      orElse: () => snapshot.syncStatus,
    );
    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final horizontalPad = compact ? 16.0 : 20.0;
            final contentWidth = wide ? 1120.0 : 680.0;
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    18,
                    horizontalPad,
                    28,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SettingsHeader(
                              syncStatus: syncStatus,
                              issueCount:
                                  snapshot.complianceSummary.activeCount,
                            ),
                            const SizedBox(height: 14),
                            _SummaryStrip(
                              snapshot: snapshot,
                              syncStatus: syncStatus,
                              storage: storage,
                            ),
                            const SizedBox(height: 14),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _SyncSection(
                                          status: syncStatus,
                                          busy: _syncBusy,
                                          onConnect: _connectDrive,
                                          onSync: _syncNow,
                                        ),
                                        const SizedBox(height: 14),
                                        _DataSection(
                                          snapshot: snapshot,
                                          storage: storage,
                                          busy: _storageBusy,
                                          onChooseRoot: _chooseStorageRoot,
                                          onOpenTrash: _openTrash,
                                          onOpenBackup: _openBackupRestore,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _CustomizationSection(theme: theme),
                                        const SizedBox(height: 14),
                                        _ComplianceSection(
                                          summary: snapshot.complianceSummary,
                                          busy: _scanBusy,
                                          onScan: _scanCompliance,
                                          onReview: _openComplianceReview,
                                        ),
                                        const SizedBox(height: 14),
                                        _DiagnosticsSection(
                                          enabled: errorLogEnabled,
                                          busy: _errorLogBusy,
                                          onChanged: _setErrorLogging,
                                        ),
                                        const SizedBox(height: 14),
                                        _DangerZoneSection(
                                          onOpen: _openDangerZone,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _SyncSection(
                                status: syncStatus,
                                busy: _syncBusy,
                                onConnect: _connectDrive,
                                onSync: _syncNow,
                              ),
                              const SizedBox(height: 14),
                              _CustomizationSection(theme: theme),
                              const SizedBox(height: 14),
                              _DataSection(
                                snapshot: snapshot,
                                storage: storage,
                                busy: _storageBusy,
                                onChooseRoot: _chooseStorageRoot,
                                onOpenTrash: _openTrash,
                                onOpenBackup: _openBackupRestore,
                              ),
                              const SizedBox(height: 14),
                              _ComplianceSection(
                                summary: snapshot.complianceSummary,
                                busy: _scanBusy,
                                onScan: _scanCompliance,
                                onReview: _openComplianceReview,
                              ),
                              const SizedBox(height: 14),
                              _DiagnosticsSection(
                                enabled: errorLogEnabled,
                                busy: _errorLogBusy,
                                onChanged: _setErrorLogging,
                              ),
                              const SizedBox(height: 14),
                              _DangerZoneSection(onOpen: _openDangerZone),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _compactError(Object error) {
  if (error is GoogleSignInException) {
    return _compactGoogleSignInError(error);
  }
  final message = error.toString();
  if (message.length <= 96) {
    return message;
  }
  return '${message.substring(0, 93)}...';
}

String _compactGoogleSignInError(GoogleSignInException error) {
  return switch (error.code) {
    GoogleSignInExceptionCode.clientConfigurationError ||
    GoogleSignInExceptionCode.providerConfigurationError =>
      'Google Sign-In configuration failed. Check web client ID, package name, and SHA-1.',
    GoogleSignInExceptionCode.canceled =>
      'Google sign-in was canceled. If this followed account selection, check Android OAuth setup.',
    GoogleSignInExceptionCode.uiUnavailable =>
      'Google sign-in UI is unavailable on this device.',
    GoogleSignInExceptionCode.interrupted => 'Google sign-in was interrupted.',
    _ => _compactText(error.description ?? error.toString()),
  };
}

String _compactText(String message) {
  if (message.length <= 96) {
    return message;
  }
  return '${message.substring(0, 93)}...';
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.syncStatus, required this.issueCount});

  final SyncStatus syncStatus;
  final int issueCount;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: palette.accentSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.tune_rounded, color: palette.accent, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_syncPhaseLabel(syncStatus)} · $issueCount active issues',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.snapshot,
    required this.syncStatus,
    required this.storage,
  });

  final LibrarySnapshot snapshot;
  final SyncStatus syncStatus;
  final AsyncValue<StorageStatus> storage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final tiles = <Widget>[
          _MetricTile(
            icon: Icons.note_alt_rounded,
            label: 'Notes',
            value: snapshot.notes.length.toString(),
          ),
          _MetricTile(
            icon: Icons.dashboard_customize_rounded,
            label: 'Templates',
            value: snapshot.templates.length.toString(),
          ),
          _MetricTile(
            icon: Icons.delete_outline_rounded,
            label: 'Trash',
            value: snapshot.trash.length.toString(),
          ),
          _MetricTile(
            icon: Icons.folder_rounded,
            label: 'Storage',
            value: storage.maybeWhen(
              data: (status) => status.isAvailable ? 'Ready' : 'Blocked',
              orElse: () => 'Checking',
            ),
          ),
        ];
        if (compact) {
          return Wrap(spacing: 8, runSpacing: 8, children: tiles);
        }
        return Row(
          children: tiles.map((tile) => Expanded(child: tile)).toList(),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      margin: const EdgeInsetsDirectional.only(end: 8),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: palette.accent, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncSection extends StatelessWidget {
  const _SyncSection({
    required this.status,
    required this.busy,
    required this.onConnect,
    required this.onSync,
  });

  final SyncStatus status;
  final bool busy;
  final VoidCallback onConnect;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final running =
        busy ||
        status.phase == SyncPhase.signingIn ||
        status.phase == SyncPhase.scanning ||
        status.phase == SyncPhase.syncing;
    return _SettingsSection(
      icon: Icons.cloud_sync_rounded,
      title: 'Sync',
      subtitle: status.message ?? _syncPhaseLabel(status),
      trailing: _StatusPill(
        label: _syncPhaseLabel(status),
        color: _syncColor(status, palette),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  icon: status.signedIn
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  label: 'Google Drive',
                  value: status.signedIn ? 'Connected' : 'Not connected',
                ),
              ),
              const SizedBox(width: 8),
              OrgIconButton(
                icon: Icons.login_rounded,
                tooltip: 'Connect Drive',
                onPressed: running ? null : onConnect,
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Last sync',
            value: status.lastSyncAt == null
                ? 'Never'
                : _relativeTime(status.lastSyncAt!),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  icon: Icons.pending_actions_rounded,
                  label: 'Pending',
                  value: status.pendingChanges.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoRow(
                  icon: Icons.warning_amber_rounded,
                  label: 'Conflicts',
                  value: status.conflictCount.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FullWidthButton(
            icon: running ? Icons.hourglass_top_rounded : Icons.sync_rounded,
            label: running ? 'Working' : 'Sync now',
            onTap: running ? null : onSync,
          ),
        ],
      ),
    );
  }
}

class _CustomizationSection extends ConsumerWidget {
  const _CustomizationSection({required this.theme});

  final ThemeState theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = OrgPaletteScope.of(context);
    final notifier = ref.read(themeProvider.notifier);
    return _SettingsSection(
      icon: Icons.palette_rounded,
      title: 'Customization',
      subtitle:
          '${_themeLabel(theme.themePreference)} · ${_accentName(theme.accentHue)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Subhead(label: 'Theme'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preference in ThemePreference.values)
                _ChoicePill(
                  label: _themeLabel(preference),
                  icon: _themeIcon(preference),
                  selected: theme.themePreference == preference,
                  onTap: () => notifier.setThemePreference(preference),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Subhead(label: 'Accent'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final accent in OrgAccents.presets)
                _AccentSwatch(
                  accent: accent,
                  selected: theme.accentHue == accent.hue,
                  onTap: () => notifier.setAccentHue(accent.hue),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _SwitchRow(
            icon: Icons.dark_mode_rounded,
            label: 'OLED black',
            value: theme.resolveOled(palette.brightness),
            enabled:
                theme.resolveBrightness(palette.brightness) == Brightness.dark,
            onChanged: (value) => notifier.setOled(value),
          ),
          const SizedBox(height: 10),
          _Subhead(label: 'Loading'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final animation in OrgLoadingAnimation.values)
                _ChoicePill(
                  label: _loadingLabel(animation),
                  icon: _loadingIcon(animation),
                  selected: theme.loadingAnimation == animation,
                  onTap: () => notifier.setLoadingAnimation(animation),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection({
    required this.snapshot,
    required this.storage,
    required this.busy,
    required this.onChooseRoot,
    required this.onOpenTrash,
    required this.onOpenBackup,
  });

  final LibrarySnapshot snapshot;
  final AsyncValue<StorageStatus> storage;
  final bool busy;
  final VoidCallback onChooseRoot;
  final VoidCallback onOpenTrash;
  final VoidCallback onOpenBackup;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: Icons.storage_rounded,
      title: 'Data',
      subtitle: storage.maybeWhen(
        data: (status) => status.rootLabel ?? 'Storage ready',
        orElse: () => 'Checking storage',
      ),
      child: Column(
        children: [
          storage.when(
            data: (status) => _InfoRow(
              icon: status.isAvailable
                  ? Icons.folder_rounded
                  : Icons.folder_off_rounded,
              label: 'Location',
              value: status.isAvailable
                  ? status.rootLabel ?? 'Organote'
                  : status.message ?? 'Unavailable',
            ),
            loading: () => const _InfoRow(
              icon: Icons.hourglass_top_rounded,
              label: 'Location',
              value: 'Checking',
            ),
            error: (_, _) => const _InfoRow(
              icon: Icons.error_outline_rounded,
              label: 'Location',
              value: 'Unavailable',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  icon: Icons.note_alt_rounded,
                  label: 'Notes',
                  value: snapshot.notes.length.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Trash',
                  value: snapshot.trash.length.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FullWidthButton(
            icon: busy
                ? Icons.hourglass_top_rounded
                : Icons.folder_open_rounded,
            label: busy ? 'Working' : 'Choose storage',
            onTap: busy ? null : onChooseRoot,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FullWidthButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Open trash',
                  onTap: onOpenTrash,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FullWidthButton(
                  icon: Icons.archive_rounded,
                  label: 'Backup',
                  onTap: onOpenBackup,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComplianceSection extends StatelessWidget {
  const _ComplianceSection({
    required this.summary,
    required this.busy,
    required this.onScan,
    required this.onReview,
  });

  final ComplianceSummary summary;
  final bool busy;
  final VoidCallback onScan;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final statusColor = summary.errorCount > 0
        ? palette.danger
        : summary.activeCount > 0
        ? palette.warning
        : palette.success;
    return _SettingsSection(
      icon: Icons.fact_check_rounded,
      title: 'Compliance',
      subtitle: '${summary.activeCount} active · ${summary.errorCount} errors',
      trailing: _StatusPill(
        label: summary.activeCount == 0 ? 'Clean' : 'Review',
        color: statusColor,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  icon: Icons.rule_rounded,
                  label: 'Active',
                  value: summary.activeCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoRow(
                  icon: Icons.error_outline_rounded,
                  label: 'Errors',
                  value: summary.errorCount.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FullWidthButton(
                  icon: Icons.rule_folder_rounded,
                  label: 'Review issues',
                  onTap: onReview,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FullWidthButton(
                  icon: busy
                      ? Icons.hourglass_top_rounded
                      : Icons.refresh_rounded,
                  label: busy ? 'Scanning' : 'Scan now',
                  onTap: busy ? null : onScan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return _SettingsSection(
      icon: Icons.receipt_long_rounded,
      title: 'Diagnostics',
      subtitle: enabled ? 'Error log on' : 'Error log off',
      trailing: _StatusPill(
        label: enabled ? 'On' : 'Off',
        color: enabled ? palette.success : palette.textTertiary,
      ),
      child: Column(
        children: [
          _SwitchRow(
            icon: Icons.bug_report_rounded,
            label: 'Save error log',
            value: enabled,
            enabled: !busy,
            onChanged: onChanged,
            switchKey: const ValueKey<String>('settings.errorLog.switch'),
          ),
          const SizedBox(height: 8),
          const _InfoRow(
            icon: Icons.description_rounded,
            label: 'File',
            value: '.organote/errors.log',
          ),
        ],
      ),
    );
  }
}

class _DangerZoneSection extends StatelessWidget {
  const _DangerZoneSection({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return _SettingsSection(
      icon: Icons.warning_rounded,
      title: 'Danger Zone',
      subtitle: 'Permanent local storage actions',
      trailing: _StatusPill(label: 'Careful', color: palette.danger),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.delete_forever_rounded,
            label: 'Wipe flow',
            value: 'Typed confirm',
          ),
          const SizedBox(height: 12),
          _FullWidthButton(
            icon: Icons.warning_rounded,
            label: 'Open danger zone',
            onTap: onOpen,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadowSoft,
            blurRadius: 22,
            offset: const Offset(0, 12),
            spreadRadius: -18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: palette.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsetsDirectional.fromSTEB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.textTertiary, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullWidthButton extends StatefulWidget {
  const _FullWidthButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  State<_FullWidthButton> createState() => _FullWidthButtonState();
}

class _FullWidthButtonState extends State<_FullWidthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final disabled = widget.onTap == null;
    final activeColor = widget.destructive ? palette.danger : palette.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: OrgDurations.press,
        curve: OrgCurves.spring,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: disabled ? palette.surfaceHigh : activeColor,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 17,
                color: disabled ? palette.textTertiary : palette.onAccent,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: disabled ? palette.textTertiary : palette.onAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
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
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: OrgDurations.toggle,
        curve: OrgCurves.snap,
        padding: const EdgeInsetsDirectional.fromSTEB(11, 8, 12, 8),
        decoration: BoxDecoration(
          color: selected ? palette.accentSoft : palette.bgSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? palette.accent.withAlpha(120) : palette.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? palette.accent : palette.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? palette.accent : palette.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final OrgAccentPreset accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Tooltip(
      message: accent.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: OrgDurations.toggle,
          curve: OrgCurves.snap,
          width: 48,
          height: 38,
          decoration: BoxDecoration(
            color: accent.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? palette.text : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.color.withAlpha(selected ? 95 : 40),
                blurRadius: selected ? 20 : 10,
                offset: const Offset(0, 8),
                spreadRadius: -8,
              ),
            ],
          ),
          child: selected
              ? Icon(Icons.check_rounded, color: palette.onAccent, size: 18)
              : null,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.switchKey,
  });

  final IconData icon;
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(11, 7, 7, 7),
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.textTertiary, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? palette.textSecondary : palette.textTertiary,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
          Switch.adaptive(
            key: switchKey,
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: palette.accent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(9, 6, 9, 6),
      decoration: BoxDecoration(
        color: color.withAlpha(32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.isDark ? color : color.withAlpha(230),
          fontWeight: FontWeight.w900,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _Subhead extends StatelessWidget {
  const _Subhead({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: palette.textTertiary,
          fontWeight: FontWeight.w900,
          fontSize: 10.5,
          letterSpacing: 0.08,
        ),
      ),
    );
  }
}

String _syncPhaseLabel(SyncStatus status) {
  return switch (status.phase) {
    SyncPhase.idle => status.signedIn ? 'Ready' : 'Offline',
    SyncPhase.signingIn => 'Signing in',
    SyncPhase.scanning => 'Scanning',
    SyncPhase.syncing => 'Syncing',
    SyncPhase.complete => 'Complete',
    SyncPhase.error => 'Error',
  };
}

Color _syncColor(SyncStatus status, OrgPalette palette) {
  return switch (status.phase) {
    SyncPhase.error => palette.danger,
    SyncPhase.complete => palette.success,
    SyncPhase.scanning ||
    SyncPhase.syncing ||
    SyncPhase.signingIn => palette.warning,
    SyncPhase.idle => status.signedIn ? palette.success : palette.textTertiary,
  };
}

String _themeLabel(ThemePreference preference) {
  return switch (preference) {
    ThemePreference.system => 'Auto',
    ThemePreference.light => 'Light',
    ThemePreference.dark => 'Dark',
    ThemePreference.oled => 'OLED',
  };
}

IconData _themeIcon(ThemePreference preference) {
  return switch (preference) {
    ThemePreference.system => Icons.brightness_auto_rounded,
    ThemePreference.light => Icons.light_mode_rounded,
    ThemePreference.dark => Icons.dark_mode_rounded,
    ThemePreference.oled => Icons.contrast_rounded,
  };
}

String _accentName(double hue) {
  for (final accent in OrgAccents.presets) {
    if (accent.hue == hue) return accent.name;
  }
  return '${hue.toStringAsFixed(0)} deg';
}

String _loadingLabel(OrgLoadingAnimation animation) {
  return switch (animation) {
    OrgLoadingAnimation.ripple => 'Ripple',
    OrgLoadingAnimation.stagger => 'Stagger',
    OrgLoadingAnimation.orbit => 'Orbit',
    OrgLoadingAnimation.pulse => 'Pulse',
  };
}

IconData _loadingIcon(OrgLoadingAnimation animation) {
  return switch (animation) {
    OrgLoadingAnimation.ripple => Icons.radar_rounded,
    OrgLoadingAnimation.stagger => Icons.stacked_line_chart_rounded,
    OrgLoadingAnimation.orbit => Icons.blur_circular_rounded,
    OrgLoadingAnimation.pulse => Icons.graphic_eq_rounded,
  };
}

String _relativeTime(DateTime date) {
  final delta = DateTime.now().toUtc().difference(date.toUtc());
  if (delta.inMinutes < 1) return 'Just now';
  if (delta.inHours < 1) return '${delta.inMinutes} min ago';
  if (delta.inDays < 1) return '${delta.inHours} h ago';
  if (delta.inDays < 30) return '${delta.inDays} d ago';
  final months = (delta.inDays / 30).floor();
  if (months < 12) return '$months mo ago';
  return '${(delta.inDays / 365).floor()} y ago';
}
