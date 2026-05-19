import '../../domain/models/models.dart';
import 'sync_models.dart';

class SyncReconciler {
  const SyncReconciler();

  List<SyncPlanAction> reconcile({
    required Map<String, SyncManifestEntry> local,
    required Map<String, SyncManifestEntry> remote,
    required Map<String, SyncLedgerEntry> ledger,
    Set<String> trashedOriginalPaths = const <String>{},
    Set<String> referencedAssetPaths = const <String>{},
  }) {
    final paths = <String>{...local.keys, ...remote.keys, ...ledger.keys};
    final actions = <SyncPlanAction>[];

    for (final path in paths) {
      final localEntry = local[path];
      final remoteEntry = remote[path];
      final ledgerEntry = ledger[path];

      if (remoteEntry?.softDeleted == true) {
        actions.add(
          SyncPlanAction(
            type: localEntry == null
                ? SyncPlanActionType.pruneLedger
                : SyncPlanActionType.deleteLocal,
            relativePath: path,
            reason: 'Remote soft-delete flag.',
          ),
        );
        continue;
      }

      if (_shouldSkipAsset(path, remoteEntry, referencedAssetPaths)) {
        continue;
      }

      if (remoteEntry != null && localEntry == null && ledgerEntry == null) {
        actions.add(
          SyncPlanAction(
            type: trashedOriginalPaths.contains(path)
                ? SyncPlanActionType.pushSoftDelete
                : SyncPlanActionType.downloadRemote,
            relativePath: path,
            reason: trashedOriginalPaths.contains(path)
                ? 'Zombie remote file exists in local trash.'
                : 'Remote new.',
          ),
        );
        continue;
      }

      if (localEntry != null && remoteEntry == null && ledgerEntry == null) {
        actions.add(
          SyncPlanAction(
            type: SyncPlanActionType.uploadLocal,
            relativePath: path,
            reason: 'Local new.',
          ),
        );
        continue;
      }

      if (localEntry != null && remoteEntry != null && ledgerEntry != null) {
        final localChanged = localEntry.checksum != ledgerEntry.localChecksum;
        final remoteChanged = remoteEntry.modifiedAt.isAfter(
          ledgerEntry.remoteModifiedAt,
        );
        if (localChanged && remoteChanged) {
          actions.add(
            SyncPlanAction(
              type: remoteEntry.modifiedAt.isAfter(localEntry.modifiedAt)
                  ? SyncPlanActionType.downloadRemoteConflictWinner
                  : SyncPlanActionType.uploadLocalConflictWinner,
              relativePath: path,
              reason: 'Conflict resolved by remote clock last-write-wins.',
            ),
          );
        } else if (localChanged) {
          actions.add(
            SyncPlanAction(
              type: SyncPlanActionType.uploadLocal,
              relativePath: path,
              reason: 'Local changed.',
            ),
          );
        } else if (remoteChanged) {
          actions.add(
            SyncPlanAction(
              type: SyncPlanActionType.downloadRemote,
              relativePath: path,
              reason: 'Remote changed.',
            ),
          );
        } else {
          actions.add(
            SyncPlanAction(
              type: SyncPlanActionType.none,
              relativePath: path,
              reason: 'Unchanged.',
            ),
          );
        }
        continue;
      }

      if (localEntry == null && remoteEntry != null && ledgerEntry != null) {
        actions.add(
          SyncPlanAction(
            type: SyncPlanActionType.pushSoftDelete,
            relativePath: path,
            reason: 'Local deletion.',
          ),
        );
        continue;
      }

      if (localEntry != null && remoteEntry == null && ledgerEntry != null) {
        actions.add(
          SyncPlanAction(
            type: SyncPlanActionType.deleteLocal,
            relativePath: path,
            reason: 'Remote deletion.',
          ),
        );
        continue;
      }

      if (localEntry == null && remoteEntry == null && ledgerEntry != null) {
        actions.add(
          SyncPlanAction(
            type: SyncPlanActionType.pruneLedger,
            relativePath: path,
            reason: 'Deleted everywhere.',
          ),
        );
      }
    }

    actions.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return actions;
  }

  static bool _shouldSkipAsset(
    String path,
    SyncManifestEntry? remoteEntry,
    Set<String> referencedAssetPaths,
  ) {
    if (remoteEntry?.isAsset != true && !path.startsWith('assets/')) {
      return false;
    }
    return referencedAssetPaths.isNotEmpty &&
        !referencedAssetPaths.contains(path);
  }
}
