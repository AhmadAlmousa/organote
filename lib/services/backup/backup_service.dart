import 'package:archive/archive.dart';

import '../storage/file_store.dart';

class BackupService {
  const BackupService(this._fileStore);

  final FileStore _fileStore;

  Future<List<int>> createBackupZip() async {
    final archive = Archive();
    final files = await _fileStore.listFiles('', recursive: true);
    for (final file in files) {
      if (!file.relativePath.startsWith('templates/') &&
          !file.relativePath.startsWith('notes/') &&
          !file.relativePath.startsWith('assets/') &&
          !file.relativePath.startsWith('trash/') &&
          !file.relativePath.startsWith('.organote/')) {
        continue;
      }
      archive.addFile(
        ArchiveFile.bytes(
          file.relativePath,
          await _fileStore.readBytes(file.relativePath),
        ),
      );
    }
    return ZipEncoder().encode(archive);
  }

  Future<void> restoreBackupZip(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive.files) {
      if (!entry.isFile) {
        continue;
      }
      final path = normalizeRelativePath(entry.name);
      await _fileStore.writeBytes(path, entry.content);
    }
    await _fileStore.ensureStructure();
  }
}
