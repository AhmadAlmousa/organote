import 'package:flutter_test/flutter_test.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/services/sync/sync_models.dart';
import 'package:organote/services/sync/sync_reconciler.dart';

void main() {
  group('SyncReconciler', () {
    const reconciler = SyncReconciler();
    final t1 = DateTime.utc(2026);
    final t2 = DateTime.utc(2026, 1, 2);
    final t3 = DateTime.utc(2026, 1, 3);

    SyncManifestEntry entry(String path, String checksum, DateTime modifiedAt) {
      return SyncManifestEntry(
        relativePath: path,
        checksum: checksum,
        modifiedAt: modifiedAt,
      );
    }

    SyncLedgerEntry ledger(String path) {
      return SyncLedgerEntry(
        relativePath: path,
        localChecksum: 'old',
        remoteModifiedAt: t1,
        localSyncedAt: t1,
      );
    }

    test(
      'handles remote new, local new, local deletion, remote deletion, and prune',
      () {
        final actions = reconciler.reconcile(
          local: {
            'local.md': entry('local.md', 'a', t2),
            'remote-deleted.md': entry('remote-deleted.md', 'old', t1),
          },
          remote: {
            'remote.md': entry('remote.md', 'b', t2),
            'local-deleted.md': entry('local-deleted.md', 'old', t1),
          },
          ledger: {
            'remote-deleted.md': ledger('remote-deleted.md'),
            'local-deleted.md': ledger('local-deleted.md'),
            'gone.md': ledger('gone.md'),
          },
        );

        expect(_type(actions, 'remote.md'), SyncPlanActionType.downloadRemote);
        expect(_type(actions, 'local.md'), SyncPlanActionType.uploadLocal);
        expect(
          _type(actions, 'local-deleted.md'),
          SyncPlanActionType.pushSoftDelete,
        );
        expect(
          _type(actions, 'remote-deleted.md'),
          SyncPlanActionType.deleteLocal,
        );
        expect(_type(actions, 'gone.md'), SyncPlanActionType.pruneLedger);
      },
    );

    test('uses remote clock last-write-wins for conflicts', () {
      final downloadWinner = reconciler.reconcile(
        local: {'note.md': entry('note.md', 'local', t2)},
        remote: {'note.md': entry('note.md', 'remote', t3)},
        ledger: {'note.md': ledger('note.md')},
      );
      final uploadWinner = reconciler.reconcile(
        local: {'note.md': entry('note.md', 'local', t3)},
        remote: {'note.md': entry('note.md', 'remote', t2)},
        ledger: {'note.md': ledger('note.md')},
      );

      expect(
        _type(downloadWinner, 'note.md'),
        SyncPlanActionType.downloadRemoteConflictWinner,
      );
      expect(
        _type(uploadWinner, 'note.md'),
        SyncPlanActionType.uploadLocalConflictWinner,
      );
    });

    test('intercepts zombie remote files and filters unreferenced assets', () {
      final actions = reconciler.reconcile(
        local: const {},
        remote: {
          'notes/deleted.md': entry('notes/deleted.md', 'r', t2),
          'assets/unused.png': SyncManifestEntry(
            relativePath: 'assets/unused.png',
            checksum: 'r',
            modifiedAt: t2,
            isAsset: true,
          ),
        },
        ledger: const {},
        trashedOriginalPaths: {'notes/deleted.md'},
        referencedAssetPaths: {'assets/used.png'},
      );

      expect(
        _type(actions, 'notes/deleted.md'),
        SyncPlanActionType.pushSoftDelete,
      );
      expect(
        actions.any((action) => action.relativePath == 'assets/unused.png'),
        isFalse,
      );
    });
  });
}

SyncPlanActionType _type(List<SyncPlanAction> actions, String path) {
  return actions.singleWhere((action) => action.relativePath == path).type;
}
