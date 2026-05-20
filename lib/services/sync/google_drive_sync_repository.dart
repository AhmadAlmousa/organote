import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as google_auth;

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../storage/file_store.dart';
import 'google_drive_remote_file_provider.dart';
import 'remote_file_provider.dart';
import 'sync_ledger_store.dart';
import 'sync_models.dart';
import 'sync_reconciler.dart';

const _googleSignInClientId = String.fromEnvironment(
  'GOOGLE_SIGN_IN_CLIENT_ID',
);
const _googleSignInServerClientId = String.fromEnvironment(
  'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
);

String? _blankToNull(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _configuredValue({
  required String key,
  required String defineValue,
  String? override,
}) {
  final value =
      _blankToNull(override) ??
      _blankToNull(defineValue) ??
      _blankToNull(dotenv.isInitialized ? dotenv.maybeGet(key) : null);
  if (_isPlaceholderClientId(value)) {
    return null;
  }
  return value;
}

bool _isPlaceholderClientId(String? value) {
  final lower = value?.toLowerCase();
  if (lower == null) {
    return false;
  }
  return lower.contains('replace-me') ||
      lower.contains('<') ||
      lower.contains('your_');
}

class GoogleDriveSyncRepository implements SyncRepository {
  GoogleDriveSyncRepository({
    required FileStore fileStore,
    SyncReconciler reconciler = const SyncReconciler(),
    SyncLedgerStore? ledgerStore,
    RemoteFileProvider? remoteFileProvider,
    GoogleSignIn? googleSignIn,
    String? clientId,
    String? serverClientId,
  }) : _fileStore = fileStore,
       _reconciler = reconciler,
       _ledgerStore = ledgerStore ?? SyncLedgerStore(fileStore),
       _remoteProvider = remoteFileProvider,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _clientId = _configuredValue(
         key: 'GOOGLE_SIGN_IN_CLIENT_ID',
         defineValue: _googleSignInClientId,
         override: clientId,
       ),
       _serverClientId = _configuredValue(
         key: 'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
         defineValue: _googleSignInServerClientId,
         override: serverClientId,
       ) {
    _statusController.add(const SyncStatus());
  }

  static const scopes = <String>[drive.DriveApi.driveFileScope];

  final FileStore _fileStore;
  final SyncReconciler _reconciler;
  final SyncLedgerStore _ledgerStore;
  final GoogleSignIn _googleSignIn;
  final String? _clientId;
  final String? _serverClientId;
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  bool _initialized = false;
  google_auth.AuthClient? _authClient;
  drive.DriveApi? _driveApi;
  RemoteFileProvider? _remoteProvider;
  Future<void>? _syncLock;
  Timer? _focusDebounce;

  @override
  Stream<SyncStatus> watchSyncStatus() => _statusController.stream;

  @override
  Future<void> signInGoogleDrive() async {
    _statusController.add(
      const SyncStatus(phase: SyncPhase.signingIn, message: 'Signing in'),
    );
    try {
      await _initializeGoogleSignIn();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw UnsupportedError(
          'Google Drive sync sign-in on this platform needs the Google-rendered sign-in button.',
        );
      }
      final account = await _googleSignIn.authenticate(scopeHint: scopes);
      final authorization =
          await account.authorizationClient.authorizationForScopes(scopes) ??
          await account.authorizationClient.authorizeScopes(scopes);
      _authClient = authorization.authClient(scopes: scopes);
      _driveApi = drive.DriveApi(_authClient!);
      _remoteProvider ??= GoogleDriveRemoteFileProvider(_driveApi!);
      _statusController.add(
        SyncStatus(
          phase: SyncPhase.idle,
          signedIn: true,
          message: 'Google Drive connected',
        ),
      );
    } catch (error) {
      _statusController.add(
        SyncStatus(phase: SyncPhase.error, message: _syncErrorMessage(error)),
      );
      rethrow;
    }
  }

  @override
  Future<void> syncNow() {
    final existing = _syncLock;
    if (existing != null) {
      return existing;
    }
    final run = _syncNowLocked();
    _syncLock = run.whenComplete(() => _syncLock = null);
    return _syncLock!;
  }

  void scheduleFocusedSync({Duration debounce = const Duration(seconds: 2)}) {
    _focusDebounce?.cancel();
    _focusDebounce = Timer(debounce, syncNow);
  }

  Future<void> _syncNowLocked() async {
    final remoteProvider = _remoteProvider;
    if (remoteProvider == null) {
      _statusController.add(
        const SyncStatus(
          phase: SyncPhase.error,
          message: 'Google Drive is not connected.',
        ),
      );
      return;
    }
    _statusController.add(
      const SyncStatus(phase: SyncPhase.scanning, signedIn: true),
    );

    final referencedAssets = await _referencedAssetPaths();
    final local = await _buildLocalManifest();
    final remote = await remoteProvider.listManifest(
      referencedAssetPaths: referencedAssets,
    );
    final ledger = await _ledgerStore.read();
    final actions = _reconciler.reconcile(
      local: local,
      remote: remote,
      ledger: ledger,
      trashedOriginalPaths: await _trashedOriginalPaths(),
      referencedAssetPaths: referencedAssets,
    );
    final executableActions = actions
        .where((action) => action.type != SyncPlanActionType.none)
        .toList();
    final conflicts = executableActions
        .where(
          (action) =>
              action.type == SyncPlanActionType.downloadRemoteConflictWinner ||
              action.type == SyncPlanActionType.uploadLocalConflictWinner,
        )
        .length;

    _statusController.add(
      SyncStatus(
        phase: SyncPhase.syncing,
        signedIn: true,
        pendingChanges: executableActions.length,
        conflictCount: conflicts,
      ),
    );

    for (final action in executableActions) {
      await _executeAction(
        action,
        local: local,
        remote: remote,
        ledger: ledger,
        remoteProvider: remoteProvider,
      );
    }
    await _ledgerStore.write(ledger);

    _statusController.add(
      SyncStatus(
        phase: SyncPhase.complete,
        signedIn: true,
        lastSyncAt: DateTime.now().toUtc(),
        conflictCount: conflicts,
      ),
    );
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_initialized) {
      return;
    }
    final clientId = kIsWeb || defaultTargetPlatform != TargetPlatform.android
        ? _clientId
        : null;
    final serverClientId = kIsWeb ? null : _serverClientId ?? _clientId;
    await _googleSignIn.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
    _initialized = true;
  }

  Future<Map<String, SyncManifestEntry>> _buildLocalManifest() async {
    final files = await _fileStore.listFiles('', recursive: true);
    final manifest = <String, SyncManifestEntry>{};
    for (final file in files.where(_isSyncableFile)) {
      final bytes = await _fileStore.readBytes(file.relativePath);
      manifest[file.relativePath] = SyncManifestEntry(
        relativePath: file.relativePath,
        checksum: checksumBytes(bytes),
        modifiedAt: file.modifiedAt,
        isAsset: file.relativePath.startsWith('assets/'),
      );
    }
    return manifest;
  }

  Future<Set<String>> _referencedAssetPaths() async {
    final notes = await _fileStore.listFiles('notes', recursive: true);
    final paths = <String>{};
    final assetPattern = RegExp(r'assets/[^\s\])"]+');
    for (final file in notes.where(
      (file) => file.relativePath.endsWith('.md'),
    )) {
      final source = await _fileStore.readText(file.relativePath);
      paths.addAll(
        assetPattern.allMatches(source).map((match) => match.group(0)!),
      );
    }
    return paths;
  }

  Future<Set<String>> _trashedOriginalPaths() async {
    const trashIndex = '.organote/trash.json';
    if (!await _fileStore.exists(trashIndex)) {
      return const <String>{};
    }
    final source = await _fileStore.readText(trashIndex);
    final matches = RegExp(
      r'"originalPath"\s*:\s*"([^"]+)"',
    ).allMatches(source);
    return matches.map((match) => match.group(1)!).toSet();
  }

  Future<void> _executeAction(
    SyncPlanAction action, {
    required Map<String, SyncManifestEntry> local,
    required Map<String, SyncManifestEntry> remote,
    required Map<String, SyncLedgerEntry> ledger,
    required RemoteFileProvider remoteProvider,
  }) async {
    final path = action.relativePath;
    final remoteEntry = remote[path];
    final ledgerEntry = ledger[path];
    switch (action.type) {
      case SyncPlanActionType.none:
        return;
      case SyncPlanActionType.downloadRemote:
      case SyncPlanActionType.downloadRemoteConflictWinner:
        final bytes = await remoteProvider.download(path);
        await _fileStore.writeBytes(path, bytes);
        ledger[path] = SyncLedgerEntry(
          relativePath: path,
          localChecksum: checksumBytes(bytes),
          remoteModifiedAt: remoteEntry?.modifiedAt ?? DateTime.now().toUtc(),
          localSyncedAt: DateTime.now().toUtc(),
          remoteFileId: remoteEntry?.remoteFileId,
        );
      case SyncPlanActionType.uploadLocal:
      case SyncPlanActionType.uploadLocalConflictWinner:
        final localEntry = local[path];
        if (localEntry == null) {
          return;
        }
        final bytes = await _fileStore.readBytes(path);
        final uploaded = await remoteProvider.upload(
          relativePath: path,
          bytes: bytes,
          remoteFileId: remoteEntry?.remoteFileId ?? ledgerEntry?.remoteFileId,
        );
        ledger[path] = SyncLedgerEntry(
          relativePath: path,
          localChecksum: checksumBytes(bytes),
          remoteModifiedAt: uploaded.modifiedAt,
          localSyncedAt: DateTime.now().toUtc(),
          remoteFileId: uploaded.remoteFileId,
        );
      case SyncPlanActionType.pushSoftDelete:
        await remoteProvider.pushSoftDelete(
          path,
          remoteFileId: remoteEntry?.remoteFileId ?? ledgerEntry?.remoteFileId,
        );
        ledger.remove(path);
      case SyncPlanActionType.deleteLocal:
        await _fileStore.delete(path, recursive: true);
        ledger.remove(path);
      case SyncPlanActionType.pruneLedger:
        ledger.remove(path);
    }
  }

  static bool _isSyncableFile(StoredFile file) {
    final path = file.relativePath;
    if (path == SyncLedgerStore.ledgerPath || path.startsWith('trash/')) {
      return false;
    }
    return path.startsWith('templates/') ||
        path.startsWith('notes/') ||
        path.startsWith('assets/') ||
        path == '.organote/categories.json';
  }

  void dispose() {
    _focusDebounce?.cancel();
    unawaited(_statusController.close());
    _authClient?.close();
  }
}

String _syncErrorMessage(Object error) {
  if (error is GoogleSignInException) {
    return _googleSignInErrorMessage(error);
  }
  final raw = error.toString();
  if (raw.contains('serverClientId') || raw.contains('clientConfiguration')) {
    return 'Google Sign-In is missing or rejecting the OAuth client ID.';
  }
  if (raw.length <= 140) {
    return raw;
  }
  return '${raw.substring(0, 137)}...';
}

String _googleSignInErrorMessage(GoogleSignInException error) {
  final description = error.description ?? '';
  return switch (error.code) {
    GoogleSignInExceptionCode.clientConfigurationError
        when description.contains('serverClientId') =>
      'Google Sign-In needs the web OAuth client ID as Android serverClientId.',
    GoogleSignInExceptionCode.clientConfigurationError =>
      'Google Sign-In client configuration failed. Check client ID, package, and SHA-1.',
    GoogleSignInExceptionCode.providerConfigurationError =>
      'Google Sign-In provider setup failed. Check Google Play services and OAuth setup.',
    GoogleSignInExceptionCode.canceled =>
      'Google sign-in was canceled. If this happened after account selection, check OAuth setup.',
    GoogleSignInExceptionCode.uiUnavailable =>
      'Google sign-in UI is unavailable on this device.',
    GoogleSignInExceptionCode.interrupted => 'Google sign-in was interrupted.',
    _ => description.isEmpty ? error.toString() : description,
  };
}
