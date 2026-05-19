import 'package:googleapis/drive/v3.dart' as drive;

import 'remote_file_provider.dart';
import 'sync_models.dart';

class GoogleDriveRemoteFileProvider implements RemoteFileProvider {
  GoogleDriveRemoteFileProvider(this._driveApi);

  static const _rootProperty = 'organoteRoot';
  static const _pathProperty = 'organotePath';
  static const _softDeletedProperty = 'organoteSoftDeleted';

  final drive.DriveApi _driveApi;
  String? _rootFolderId;
  final Map<String, String> _fileIdsByPath = <String, String>{};

  @override
  Future<Map<String, SyncManifestEntry>> listManifest({
    required Set<String> referencedAssetPaths,
  }) async {
    final rootId = await _ensureRootFolder();
    final result = <String, SyncManifestEntry>{};
    String? pageToken;
    do {
      final page = await _driveApi.files.list(
        q: "'$rootId' in parents and trashed=false",
        pageToken: pageToken,
        pageSize: 1000,
        $fields:
            'nextPageToken,files(id,name,md5Checksum,modifiedTime,size,appProperties)',
      );
      for (final file in page.files ?? const <drive.File>[]) {
        final path = file.appProperties?[_pathProperty];
        if (path == null || path.isEmpty) {
          continue;
        }
        final isAsset = path.startsWith('assets/');
        if (isAsset &&
            referencedAssetPaths.isNotEmpty &&
            !referencedAssetPaths.contains(path)) {
          continue;
        }
        if (file.id != null) {
          _fileIdsByPath[path] = file.id!;
        }
        result[path] = SyncManifestEntry(
          relativePath: path,
          checksum: file.md5Checksum ?? '',
          modifiedAt:
              file.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0),
          remoteFileId: file.id,
          softDeleted: file.appProperties?[_softDeletedProperty] == 'true',
          isAsset: isAsset,
        );
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return result;
  }

  @override
  Future<List<int>> download(String relativePath) async {
    final fileId = _fileIdsByPath[relativePath];
    if (fileId == null) {
      throw StateError('Remote file not found for $relativePath.');
    }
    final media =
        await _driveApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    return media.stream.expand((chunk) => chunk).toList();
  }

  @override
  Future<SyncManifestEntry> upload({
    required String relativePath,
    required List<int> bytes,
    String? remoteFileId,
  }) async {
    final rootId = await _ensureRootFolder();
    final metadata = drive.File()
      ..name = _driveSafeName(relativePath)
      ..parents = remoteFileId == null ? <String>[rootId] : null
      ..appProperties = <String, String>{
        _pathProperty: relativePath,
        _softDeletedProperty: 'false',
      };
    final media = drive.Media(Stream<List<int>>.value(bytes), bytes.length);
    final uploaded = remoteFileId == null
        ? await _driveApi.files.create(
            metadata,
            uploadMedia: media,
            $fields: 'id,md5Checksum,modifiedTime,appProperties',
          )
        : await _driveApi.files.update(
            metadata,
            remoteFileId,
            uploadMedia: media,
            $fields: 'id,md5Checksum,modifiedTime,appProperties',
          );
    if (uploaded.id != null) {
      _fileIdsByPath[relativePath] = uploaded.id!;
    }
    return SyncManifestEntry(
      relativePath: relativePath,
      checksum: uploaded.md5Checksum ?? '',
      modifiedAt: uploaded.modifiedTime ?? DateTime.now().toUtc(),
      remoteFileId: uploaded.id,
      isAsset: relativePath.startsWith('assets/'),
    );
  }

  @override
  Future<void> pushSoftDelete(
    String relativePath, {
    String? remoteFileId,
  }) async {
    final fileId = remoteFileId ?? _fileIdsByPath[relativePath];
    if (fileId == null) {
      return;
    }
    await _driveApi.files.update(
      drive.File()
        ..appProperties = <String, String>{
          _pathProperty: relativePath,
          _softDeletedProperty: 'true',
        },
      fileId,
      $fields: 'id',
    );
  }

  Future<String> _ensureRootFolder() async {
    final existing = _rootFolderId;
    if (existing != null) {
      return existing;
    }
    final page = await _driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and trashed=false and appProperties has { key='$_rootProperty' and value='true' }",
      pageSize: 1,
      $fields: 'files(id)',
    );
    final found = page.files?.firstOrNull?.id;
    if (found != null) {
      _rootFolderId = found;
      return found;
    }
    final folder = await _driveApi.files.create(
      drive.File()
        ..name = 'Organote'
        ..mimeType = 'application/vnd.google-apps.folder'
        ..appProperties = <String, String>{_rootProperty: 'true'},
      $fields: 'id',
    );
    _rootFolderId = folder.id;
    return folder.id!;
  }

  static String _driveSafeName(String relativePath) {
    return relativePath.replaceAll('/', '__');
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
