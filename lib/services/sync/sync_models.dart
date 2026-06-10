enum SyncPlanActionType {
  none,
  downloadRemote,
  uploadLocal,
  downloadRemoteConflictWinner,
  uploadLocalConflictWinner,
  adoptLedger,
  pushSoftDelete,
  deleteLocal,
  pruneLedger,
}

class SyncManifestEntry {
  const SyncManifestEntry({
    required this.relativePath,
    required this.checksum,
    required this.modifiedAt,
    this.remoteFileId,
    this.softDeleted = false,
    this.isAsset = false,
  });

  final String relativePath;
  final String checksum;
  final DateTime modifiedAt;
  final String? remoteFileId;
  final bool softDeleted;
  final bool isAsset;
}

class SyncPlanAction {
  const SyncPlanAction({
    required this.type,
    required this.relativePath,
    this.reason,
  });

  final SyncPlanActionType type;
  final String relativePath;
  final String? reason;
}
