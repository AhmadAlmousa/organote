import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/services/storage/memory_file_store.dart';
import 'package:organote/services/sync/sync_ledger_store.dart';

void main() {
  group('SyncLedgerStore', () {
    late MemoryFileStore store;
    late SyncLedgerStore ledger;

    setUp(() async {
      store = MemoryFileStore();
      await store.initialize();
      ledger = SyncLedgerStore(store);
    });

    test('returns an empty map when no ledger file exists yet', () async {
      expect(await store.exists(SyncLedgerStore.ledgerPath), isFalse);
      expect(await ledger.read(), isEmpty);
    });

    test('round trips ledger entries through json on disk', () async {
      final entry = SyncLedgerEntry(
        relativePath: 'notes/sample.md',
        localChecksum: 'abc123',
        remoteModifiedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        localSyncedAt: DateTime.utc(2026, 1, 2, 3, 4, 6),
        remoteFileId: 'drive-id-1',
      );

      await ledger.write({entry.relativePath: entry});
      final restored = await ledger.read();

      expect(restored.keys, ['notes/sample.md']);
      final restoredEntry = restored.values.single;
      expect(restoredEntry.localChecksum, 'abc123');
      expect(restoredEntry.remoteModifiedAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(restoredEntry.localSyncedAt, DateTime.utc(2026, 1, 2, 3, 4, 6));
      expect(restoredEntry.remoteFileId, 'drive-id-1');
      expect(restoredEntry.softDeleted, isFalse);
    });

    test('writes ledger entries sorted by relativePath for stable diffs', () async {
      final now = DateTime.utc(2026);
      await ledger.write({
        'notes/zeta.md': SyncLedgerEntry(
          relativePath: 'notes/zeta.md',
          localChecksum: 'z',
          remoteModifiedAt: now,
          localSyncedAt: now,
        ),
        'notes/alpha.md': SyncLedgerEntry(
          relativePath: 'notes/alpha.md',
          localChecksum: 'a',
          remoteModifiedAt: now,
          localSyncedAt: now,
        ),
        'notes/middle.md': SyncLedgerEntry(
          relativePath: 'notes/middle.md',
          localChecksum: 'm',
          remoteModifiedAt: now,
          localSyncedAt: now,
        ),
      });

      final decoded =
          jsonDecode(await store.readText(SyncLedgerStore.ledgerPath))
              as List<dynamic>;
      expect(decoded.map((entry) => (entry as Map)['relativePath']).toList(), [
        'notes/alpha.md',
        'notes/middle.md',
        'notes/zeta.md',
      ]);
    });

    test('overwrites the ledger file when writing a new snapshot', () async {
      final now = DateTime.utc(2026);
      await ledger.write({
        'notes/before.md': SyncLedgerEntry(
          relativePath: 'notes/before.md',
          localChecksum: 'b',
          remoteModifiedAt: now,
          localSyncedAt: now,
        ),
      });
      await ledger.write({
        'notes/after.md': SyncLedgerEntry(
          relativePath: 'notes/after.md',
          localChecksum: 'a',
          remoteModifiedAt: now,
          localSyncedAt: now,
        ),
      });

      final restored = await ledger.read();
      expect(restored.keys, ['notes/after.md']);
    });

    test('preserves the soft-deleted flag on entries that have one', () async {
      final now = DateTime.utc(2026);
      await ledger.write({
        'notes/gone.md': SyncLedgerEntry(
          relativePath: 'notes/gone.md',
          localChecksum: 'x',
          remoteModifiedAt: now,
          localSyncedAt: now,
          softDeleted: true,
        ),
      });

      final restored = await ledger.read();
      expect(restored['notes/gone.md']?.softDeleted, isTrue);
    });

    test('writes an empty json array when the entries map is empty', () async {
      await ledger.write(<String, SyncLedgerEntry>{});
      expect(await store.readText(SyncLedgerStore.ledgerPath), '[]');
      expect(await ledger.read(), isEmpty);
    });
  });
}
