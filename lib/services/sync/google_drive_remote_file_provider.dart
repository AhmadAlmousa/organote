import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

import '../storage/file_store.dart';
import 'remote_file_provider.dart';
import 'sync_models.dart';

class GoogleDriveRemoteFileProvider implements RemoteFileProvider {
  GoogleDriveRemoteFileProvider(this._driveApi);

  static const _rootProperty = 'organoteRoot';
  static const _pathProperty = 'organotePath';
  static const _softDeletedProperty = 'organoteSoftDeleted';
  static const _folderMimeType = 'application/vnd.google-apps.folder';

  final drive.DriveApi _driveApi;
  String? _rootFolderId;
  final Map<String, String> _folderIdsByPath = <String, String>{};
  final Map<String, String> _fileIdsByPath = <String, String>{};
  final Map<String, String> _parentIdsByPath = <String, String>{};

  @override
  Future<Map<String, SyncManifestEntry>> listManifest({
    required Set<String> referencedAssetPaths,
  }) async {
    final rootId = await _ensureRootFolder();
    _folderIdsByPath[''] = rootId;
    _fileIdsByPath.clear();
    _parentIdsByPath.clear();

    final result = <String, SyncManifestEntry>{};
    await _visitFolder(
      folderId: rootId,
      prefix: '',
      result: result,
      referencedAssetPaths: referencedAssetPaths,
    );
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
    final path = normalizeRelativePath(relativePath);
    final parentId = await _ensureDirectory(_directoryPath(path));
    final currentParentId = _parentIdsByPath[path];
    final movingParents =
        currentParentId != null && currentParentId != parentId;
    final metadata = drive.File()
      ..name = _fileName(path)
      ..parents = remoteFileId == null ? <String>[parentId] : null
      ..appProperties = <String, String>{
        _pathProperty: path,
        _softDeletedProperty: 'false',
      };
    final media = drive.Media(Stream<List<int>>.value(bytes), bytes.length);
    final uploaded = remoteFileId == null
        ? await _driveApi.files.create(
            metadata,
            uploadMedia: media,
            $fields: 'id,md5Checksum,modifiedTime,appProperties,parents',
          )
        : await _driveApi.files.update(
            metadata,
            remoteFileId,
            addParents: movingParents ? parentId : null,
            removeParents: movingParents ? currentParentId : null,
            uploadMedia: media,
            $fields: 'id,md5Checksum,modifiedTime,appProperties,parents',
          );
    if (uploaded.id != null) {
      _fileIdsByPath[path] = uploaded.id!;
      _parentIdsByPath[path] = uploaded.parents?.firstOrNull ?? parentId;
    }
    return SyncManifestEntry(
      relativePath: path,
      checksum: uploaded.md5Checksum ?? '',
      modifiedAt: uploaded.modifiedTime ?? DateTime.now().toUtc(),
      remoteFileId: uploaded.id,
      isAsset: path.startsWith('assets/'),
    );
  }

  @override
  Future<void> pushSoftDelete(
    String relativePath, {
    String? remoteFileId,
  }) async {
    final path = normalizeRelativePath(relativePath);
    final fileId = remoteFileId ?? _fileIdsByPath[path];
    if (fileId == null) {
      return;
    }
    await _driveApi.files.update(
      drive.File()..trashed = true,
      fileId,
      $fields: 'id',
    );
    _fileIdsByPath.remove(path);
    _parentIdsByPath.remove(path);
  }

  Future<void> _visitFolder({
    required String folderId,
    required String prefix,
    required Map<String, SyncManifestEntry> result,
    required Set<String> referencedAssetPaths,
  }) async {
    String? pageToken;
    do {
      final page = await _driveApi.files.list(
        q: "'${_queryLiteral(folderId)}' in parents and trashed=false",
        pageToken: pageToken,
        pageSize: 1000,
        $fields:
            'nextPageToken,files(id,name,mimeType,md5Checksum,modifiedTime,size,appProperties,parents)',
      );
      for (final file in page.files ?? const <drive.File>[]) {
        final fileId = file.id;
        final fileName = file.name;
        if (fileId == null || fileName == null || fileName.isEmpty) {
          continue;
        }

        final physicalPath = normalizeRelativePath(
          p.posix.join(prefix, fileName),
        );
        if (file.mimeType == _folderMimeType) {
          _folderIdsByPath[physicalPath] = fileId;
          await _visitFolder(
            folderId: fileId,
            prefix: physicalPath,
            result: result,
            referencedAssetPaths: referencedAssetPaths,
          );
          continue;
        }

        final legacyPath = _legacyFlattenedPath(file, physicalPath, prefix);
        final path = legacyPath ?? physicalPath;
        final manifestFile = legacyPath == null
            ? file
            : await _moveFileToPath(file, path, currentParentId: folderId);
        final manifestFileId = manifestFile.id;
        if (manifestFileId == null) {
          continue;
        }

        final isAsset = path.startsWith('assets/');
        if (isAsset &&
            referencedAssetPaths.isNotEmpty &&
            !referencedAssetPaths.contains(path)) {
          continue;
        }

        _fileIdsByPath[path] = manifestFileId;
        _parentIdsByPath[path] =
            manifestFile.parents?.firstOrNull ??
            _directoryIdFromPath(path) ??
            folderId;
        result[path] = SyncManifestEntry(
          relativePath: path,
          checksum: manifestFile.md5Checksum ?? '',
          modifiedAt:
              manifestFile.modifiedTime ??
              DateTime.fromMillisecondsSinceEpoch(0),
          remoteFileId: manifestFileId,
          softDeleted:
              manifestFile.appProperties?[_softDeletedProperty] == 'true',
          isAsset: isAsset,
        );
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
  }

  Future<String> _ensureRootFolder() async {
    final existing = _rootFolderId;
    if (existing != null) {
      return existing;
    }
    final page = await _driveApi.files.list(
      q: "mimeType='$_folderMimeType' and trashed=false and appProperties has { key='$_rootProperty' and value='true' }",
      pageSize: 1,
      $fields: 'files(id)',
    );
    final found = page.files?.firstOrNull?.id;
    if (found != null) {
      _rootFolderId = found;
      _folderIdsByPath[''] = found;
      return found;
    }
    final folder = await _driveApi.files.create(
      drive.File()
        ..name = 'Organote'
        ..mimeType = _folderMimeType
        ..appProperties = <String, String>{_rootProperty: 'true'},
      $fields: 'id',
    );
    _rootFolderId = folder.id;
    _folderIdsByPath[''] = folder.id!;
    return folder.id!;
  }

  Future<String> _ensureDirectory(String relativeDirectory) async {
    final path = normalizeRelativePath(relativeDirectory);
    final cached = _folderIdsByPath[path];
    if (cached != null) {
      return cached;
    }

    var parentId = await _ensureRootFolder();
    var currentPath = '';
    for (final part in path.split('/').where((part) => part.isNotEmpty)) {
      currentPath = normalizeRelativePath(p.posix.join(currentPath, part));
      final existing = _folderIdsByPath[currentPath];
      if (existing != null) {
        parentId = existing;
        continue;
      }

      final page = await _driveApi.files.list(
        q:
            "'${_queryLiteral(parentId)}' in parents and "
            "mimeType='$_folderMimeType' and "
            "name='${_queryLiteral(part)}' and trashed=false",
        pageSize: 1,
        $fields: 'files(id)',
      );
      final found = page.files?.firstOrNull?.id;
      if (found != null) {
        _folderIdsByPath[currentPath] = found;
        parentId = found;
        continue;
      }

      final created = await _driveApi.files.create(
        drive.File()
          ..name = part
          ..mimeType = _folderMimeType
          ..parents = <String>[parentId]
          ..appProperties = <String, String>{_pathProperty: currentPath},
        $fields: 'id',
      );
      parentId = created.id!;
      _folderIdsByPath[currentPath] = parentId;
    }
    return parentId;
  }

  Future<drive.File> _moveFileToPath(
    drive.File file,
    String relativePath, {
    required String currentParentId,
  }) async {
    final fileId = file.id;
    if (fileId == null) {
      return file;
    }
    final parentId = await _ensureDirectory(_directoryPath(relativePath));
    final updated = await _driveApi.files.update(
      drive.File()
        ..name = _fileName(relativePath)
        ..appProperties = <String, String>{
          _pathProperty: relativePath,
          _softDeletedProperty: 'false',
        },
      fileId,
      addParents: currentParentId == parentId ? null : parentId,
      removeParents: currentParentId == parentId ? null : currentParentId,
      $fields: 'id,name,md5Checksum,modifiedTime,appProperties,parents',
    );
    return updated;
  }

  String? _legacyFlattenedPath(
    drive.File file,
    String physicalPath,
    String parentPrefix,
  ) {
    final metadataPath = file.appProperties?[_pathProperty];
    if (metadataPath == null || metadataPath.isEmpty) {
      return null;
    }
    final path = normalizeRelativePath(metadataPath);
    if (path == physicalPath) {
      return null;
    }
    if (parentPrefix.isEmpty && file.name == _legacyDriveSafeName(path)) {
      return path;
    }
    return null;
  }

  String? _directoryIdFromPath(String relativePath) {
    return _folderIdsByPath[_directoryPath(relativePath)];
  }

  static String _directoryPath(String relativePath) {
    final directory = p.posix.dirname(relativePath);
    return directory == '.' ? '' : directory;
  }

  static String _fileName(String relativePath) {
    return p.posix.basename(relativePath);
  }

  static String _legacyDriveSafeName(String relativePath) {
    return relativePath.replaceAll('/', '__');
  }

  static String _queryLiteral(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
