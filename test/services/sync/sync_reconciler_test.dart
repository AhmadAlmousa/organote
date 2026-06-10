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

    SyncManifestEntry entry(
      String path,
      String checksum,
      DateTime modifiedAt, {
      bool softDeleted = false,
      bool isAsset = false,
      String? remoteFileId,
    }) {
      return SyncManifestEntry(
        relativePath: path,
        checksum: checksum,
        modifiedAt: modifiedAt,
        softDeleted: softDeleted,
        isAsset: isAsset,
        remoteFileId: remoteFileId,
      );
    }

    SyncLedgerEntry ledger(
      String path, {
      String checksum = 'old',
      DateTime? remoteModifiedAt,
    }) {
      return SyncLedgerEntry(
        relativePath: path,
        localChecksum: checksum,
        remoteModifiedAt: remoteModifiedAt ?? t1,
        localSyncedAt: t1,
      );
    }

    test('state 1: remote new triggers downloadRemote', () {
      final actions = reconciler.reconcile(
        local: const {},
        remote: {'notes/new.md': entry('notes/new.md', 'r', t2)},
        ledger: const {},
      );

      expect(_type(actions, 'notes/new.md'), SyncPlanActionType.downloadRemote);
    });

    test('state 2: local new triggers uploadLocal', () {
      final actions = reconciler.reconcile(
        local: {'notes/new.md': entry('notes/new.md', 'l', t2)},
        remote: const {},
        ledger: const {},
      );

      expect(_type(actions, 'notes/new.md'), SyncPlanActionType.uploadLocal);
    });

    test(
      'state 7a: both exist without ledger and equal checksums adopt ledger',
      () {
        final actions = reconciler.reconcile(
          local: {'notes/shared.md': entry('notes/shared.md', 'same', t2)},
          remote: {
            'notes/shared.md': entry(
              'notes/shared.md',
              'same',
              t3,
              remoteFileId: 'remote-shared',
            ),
          },
          ledger: const {},
        );

        expect(
          _type(actions, 'notes/shared.md'),
          SyncPlanActionType.adoptLedger,
        );
      },
    );

    test(
      'state 7b: both exist without ledger and remote-newer conflict downloads',
      () {
        final actions = reconciler.reconcile(
          local: {'notes/shared.md': entry('notes/shared.md', 'local', t2)},
          remote: {'notes/shared.md': entry('notes/shared.md', 'remote', t3)},
          ledger: const {},
        );

        expect(
          _type(actions, 'notes/shared.md'),
          SyncPlanActionType.downloadRemoteConflictWinner,
        );
      },
    );

    test(
      'state 7c: both exist without ledger and local-newer conflict uploads',
      () {
        final actions = reconciler.reconcile(
          local: {'notes/shared.md': entry('notes/shared.md', 'local', t3)},
          remote: {'notes/shared.md': entry('notes/shared.md', 'remote', t2)},
          ledger: const {},
        );

        expect(
          _type(actions, 'notes/shared.md'),
          SyncPlanActionType.uploadLocalConflictWinner,
        );
      },
    );

    test('state 3a: unchanged on both sides resolves to none', () {
      final actions = reconciler.reconcile(
        local: {'notes/stable.md': entry('notes/stable.md', 'same', t1)},
        remote: {'notes/stable.md': entry('notes/stable.md', 'same', t1)},
        ledger: {
          'notes/stable.md': ledger(
            'notes/stable.md',
            checksum: 'same',
            remoteModifiedAt: t1,
          ),
        },
      );

      expect(_type(actions, 'notes/stable.md'), SyncPlanActionType.none);
    });

    test('state 3b: local-only change triggers uploadLocal', () {
      final actions = reconciler.reconcile(
        local: {'notes/edited.md': entry('notes/edited.md', 'new-local', t2)},
        remote: {'notes/edited.md': entry('notes/edited.md', 'remote', t1)},
        ledger: {
          'notes/edited.md': ledger(
            'notes/edited.md',
            checksum: 'old-local',
            remoteModifiedAt: t1,
          ),
        },
      );

      expect(_type(actions, 'notes/edited.md'), SyncPlanActionType.uploadLocal);
    });

    test('state 3c: remote-only change triggers downloadRemote', () {
      final actions = reconciler.reconcile(
        local: {'notes/edited.md': entry('notes/edited.md', 'local', t1)},
        remote: {'notes/edited.md': entry('notes/edited.md', 'new-remote', t2)},
        ledger: {
          'notes/edited.md': ledger(
            'notes/edited.md',
            checksum: 'local',
            remoteModifiedAt: t1,
          ),
        },
      );

      expect(
        _type(actions, 'notes/edited.md'),
        SyncPlanActionType.downloadRemote,
      );
    });

    test(
      'state 3d: conflict with remote-newer resolves to downloadRemoteConflictWinner',
      () {
        final actions = reconciler.reconcile(
          local: {'notes/c.md': entry('notes/c.md', 'local', t2)},
          remote: {'notes/c.md': entry('notes/c.md', 'remote', t3)},
          ledger: {
            'notes/c.md': ledger(
              'notes/c.md',
              checksum: 'old',
              remoteModifiedAt: t1,
            ),
          },
        );

        expect(
          _type(actions, 'notes/c.md'),
          SyncPlanActionType.downloadRemoteConflictWinner,
        );
      },
    );

    test(
      'state 3e: conflict with local-newer resolves to uploadLocalConflictWinner',
      () {
        final actions = reconciler.reconcile(
          local: {'notes/c.md': entry('notes/c.md', 'local', t3)},
          remote: {'notes/c.md': entry('notes/c.md', 'remote', t2)},
          ledger: {
            'notes/c.md': ledger(
              'notes/c.md',
              checksum: 'old',
              remoteModifiedAt: t1,
            ),
          },
        );

        expect(
          _type(actions, 'notes/c.md'),
          SyncPlanActionType.uploadLocalConflictWinner,
        );
      },
    );

    test(
      'state 4: local deletion (ledger + remote, no local) pushes soft-delete',
      () {
        final actions = reconciler.reconcile(
          local: const {},
          remote: {
            'notes/gone-local.md': entry('notes/gone-local.md', 'r', t2),
          },
          ledger: {'notes/gone-local.md': ledger('notes/gone-local.md')},
        );

        expect(
          _type(actions, 'notes/gone-local.md'),
          SyncPlanActionType.pushSoftDelete,
        );
      },
    );

    test(
      'state 5: remote deletion (ledger + local, no remote) deletes locally',
      () {
        final actions = reconciler.reconcile(
          local: {
            'notes/gone-remote.md': entry('notes/gone-remote.md', 'l', t2),
          },
          remote: const {},
          ledger: {'notes/gone-remote.md': ledger('notes/gone-remote.md')},
        );

        expect(
          _type(actions, 'notes/gone-remote.md'),
          SyncPlanActionType.deleteLocal,
        );
      },
    );

    test('state 6: deleted everywhere prunes the orphan ledger entry', () {
      final actions = reconciler.reconcile(
        local: const {},
        remote: const {},
        ledger: {'notes/forgotten.md': ledger('notes/forgotten.md')},
      );

      expect(
        _type(actions, 'notes/forgotten.md'),
        SyncPlanActionType.pruneLedger,
      );
    });

    group('8-state presence matrix characterization', () {
      final scenarios = <_PresenceScenario>[
        const _PresenceScenario(
          name: 'local absent, remote absent, ledger absent emits no action',
          hasLocal: false,
          hasRemote: false,
          hasLedger: false,
        ),
        const _PresenceScenario(
          name: 'local absent, remote present, ledger absent downloads remote',
          hasLocal: false,
          hasRemote: true,
          hasLedger: false,
          expectedType: SyncPlanActionType.downloadRemote,
        ),
        const _PresenceScenario(
          name: 'local present, remote absent, ledger absent uploads local',
          hasLocal: true,
          hasRemote: false,
          hasLedger: false,
          expectedType: SyncPlanActionType.uploadLocal,
        ),
        const _PresenceScenario(
          name:
              'local present, remote present, ledger absent emits a conflict action',
          hasLocal: true,
          hasRemote: true,
          hasLedger: false,
          expectedType: SyncPlanActionType.downloadRemoteConflictWinner,
        ),
        const _PresenceScenario(
          name: 'local absent, remote absent, ledger present prunes ledger',
          hasLocal: false,
          hasRemote: false,
          hasLedger: true,
          expectedType: SyncPlanActionType.pruneLedger,
        ),
        const _PresenceScenario(
          name:
              'local absent, remote present, ledger present pushes soft-delete',
          hasLocal: false,
          hasRemote: true,
          hasLedger: true,
          expectedType: SyncPlanActionType.pushSoftDelete,
        ),
        const _PresenceScenario(
          name: 'local present, remote absent, ledger present deletes local',
          hasLocal: true,
          hasRemote: false,
          hasLedger: true,
          expectedType: SyncPlanActionType.deleteLocal,
        ),
        const _PresenceScenario(
          name: 'local present, remote present, ledger present emits unchanged',
          hasLocal: true,
          hasRemote: true,
          hasLedger: true,
          expectedType: SyncPlanActionType.none,
        ),
      ];

      for (final scenario in scenarios) {
        test(scenario.name, () {
          const path = 'notes/matrix.md';
          final local = scenario.hasLocal
              ? {'notes/matrix.md': entry(path, 'local', t2)}
              : const <String, SyncManifestEntry>{};
          final remote = scenario.hasRemote
              ? {'notes/matrix.md': entry(path, 'remote', t3)}
              : const <String, SyncManifestEntry>{};
          final entries = scenario.hasLedger
              ? {
                  'notes/matrix.md': ledger(
                    path,
                    checksum: scenario.hasLocal ? 'local' : 'old',
                    remoteModifiedAt: scenario.hasRemote ? t3 : t1,
                  ),
                }
              : const <String, SyncLedgerEntry>{};

          final actions = reconciler.reconcile(
            local: local,
            remote: remote,
            ledger: entries,
          );

          if (scenario.expectedType == null) {
            expect(actions, isEmpty);
          } else {
            expect(_type(actions, path), scenario.expectedType);
          }
        });
      }
    });

    test(
      'remote soft-delete flag triggers deleteLocal when local still present',
      () {
        final actions = reconciler.reconcile(
          local: {'notes/flag.md': entry('notes/flag.md', 'l', t1)},
          remote: {
            'notes/flag.md': entry('notes/flag.md', 'r', t2, softDeleted: true),
          },
          ledger: {'notes/flag.md': ledger('notes/flag.md')},
        );

        expect(_type(actions, 'notes/flag.md'), SyncPlanActionType.deleteLocal);
      },
    );

    test(
      'remote soft-delete flag prunes ledger when local is already gone',
      () {
        final actions = reconciler.reconcile(
          local: const {},
          remote: {
            'notes/flag.md': entry('notes/flag.md', 'r', t2, softDeleted: true),
          },
          ledger: {'notes/flag.md': ledger('notes/flag.md')},
        );

        expect(_type(actions, 'notes/flag.md'), SyncPlanActionType.pruneLedger);
      },
    );

    test('zombie remote (present in local trash) pushes soft-delete', () {
      final actions = reconciler.reconcile(
        local: const {},
        remote: {'notes/zombie.md': entry('notes/zombie.md', 'r', t2)},
        ledger: const {},
        trashedOriginalPaths: {'notes/zombie.md'},
      );

      expect(
        _type(actions, 'notes/zombie.md'),
        SyncPlanActionType.pushSoftDelete,
      );
    });

    test('asset filtering: unreferenced remote assets are skipped', () {
      final actions = reconciler.reconcile(
        local: const {},
        remote: {
          'assets/used.png': entry('assets/used.png', 'r', t2, isAsset: true),
          'assets/unused.png': entry(
            'assets/unused.png',
            'r',
            t2,
            isAsset: true,
          ),
        },
        ledger: const {},
        referencedAssetPaths: {'assets/used.png'},
      );

      expect(
        actions.any((action) => action.relativePath == 'assets/unused.png'),
        isFalse,
      );
      expect(
        _type(actions, 'assets/used.png'),
        SyncPlanActionType.downloadRemote,
      );
    });

    test(
      'asset filtering: empty referenced set lets all assets through (initial sync)',
      () {
        final actions = reconciler.reconcile(
          local: const {},
          remote: {
            'assets/any.png': entry('assets/any.png', 'r', t2, isAsset: true),
          },
          ledger: const {},
        );

        expect(
          _type(actions, 'assets/any.png'),
          SyncPlanActionType.downloadRemote,
        );
      },
    );

    test('actions are deterministic and sorted by path', () {
      final actions = reconciler.reconcile(
        local: {'b.md': entry('b.md', 'l', t1), 'a.md': entry('a.md', 'l', t1)},
        remote: const {},
        ledger: const {},
      );

      expect(actions.map((action) => action.relativePath).toList(), <String>[
        'a.md',
        'b.md',
      ]);
    });
  });
}

SyncPlanActionType _type(List<SyncPlanAction> actions, String path) {
  return actions.singleWhere((action) => action.relativePath == path).type;
}

class _PresenceScenario {
  const _PresenceScenario({
    required this.name,
    required this.hasLocal,
    required this.hasRemote,
    required this.hasLedger,
    this.expectedType,
  });

  final String name;
  final bool hasLocal;
  final bool hasRemote;
  final bool hasLedger;
  final SyncPlanActionType? expectedType;
}
