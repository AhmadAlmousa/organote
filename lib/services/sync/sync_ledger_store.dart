import 'dart:convert';

import '../../domain/models/models.dart';
import '../storage/file_store.dart';

class SyncLedgerStore {
  const SyncLedgerStore(this._fileStore);

  static const ledgerPath = '.organote/sync_ledger.json';

  final FileStore _fileStore;

  Future<Map<String, SyncLedgerEntry>> read() async {
    if (!await _fileStore.exists(ledgerPath)) {
      return <String, SyncLedgerEntry>{};
    }
    final decoded =
        jsonDecode(await _fileStore.readText(ledgerPath)) as List<dynamic>;
    final entries = decoded.cast<Map<String, dynamic>>().map(
      (json) => SyncLedgerEntry.fromJson(json.cast<String, Object?>()),
    );
    return {for (final entry in entries) entry.relativePath: entry};
  }

  Future<void> write(Map<String, SyncLedgerEntry> entries) {
    final sorted = entries.values.toList()
      ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return _fileStore.writeText(
      ledgerPath,
      const JsonEncoder.withIndent(
        '  ',
      ).convert(sorted.map((entry) => entry.toJson()).toList()),
    );
  }
}
