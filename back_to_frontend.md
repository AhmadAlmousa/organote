# Back To Frontend

Backend will own app scaffold, domain/data/services, storage, parsing, sync, compliance, backup, and DI. Frontend owns `lib/ui/**` and should consume only repository/view-model contracts.

Frontend must not parse markdown directly except for raw source preview/editor. Use:
- `LibraryRepository.watchLibrary()` for Home/Templates/Settings data.
- `NoteRepository.getNote(id)`, `getRawSource(id)`, `saveStructuredNote(input)`, `saveRawSource(id, source)`, `setPinned(id, value)`, `setFavorite(id, value)`, `softDeleteNote(id)`.
- `NoteRepository.watchTrash()` or `LibrarySnapshot.trash` for Trash UI data.
- `TemplateRepository.saveTemplate(input)` and `ComplianceRepository.watchComplianceSummary()`.
- `AssetRepository.importImageForNote(...)` and `readAssetBytes(relativePath)` for image fields.
- `SyncRepository.signInGoogleDrive()`, `syncNow()`, `watchSyncStatus()`.

Implemented backend entry points:
- DI lives in `lib/di/service_locator.dart`. Frontend can read repositories with `getIt<LibraryRepository>()`, `getIt<NoteRepository>()`, etc.
- Shared model exports live in `lib/domain/models/models.dart`.
- Repository contract exports live in `lib/domain/repositories/repositories.dart`.
- The temporary shell in `lib/ui/app_shell.dart` is only a backend smoke screen and can be replaced by the frontend.

Implemented storage behavior:
- Native/Android uses `NativeFileStore` with a default app-documents `Organote` directory and `FilePicker.getDirectoryPath()` for user-selected folders.
- Web uses strict File System Access mode through `web/organote_file_system.js`; no IndexedDB primary store exists.
- Web setup must call `FileStore.chooseRootDirectory()` from a direct user gesture. If `FileStore.getStatus()` is unavailable, show the returned `StorageStatus.message`.
- `StorageStatus.rootLabel` is intended for direct Settings display. Native defaults to `Organote (app documents)` for the automatic app-documents root and chosen folders include their basename plus full path. Web returns `<folder> (chosen folder)`.

Implemented file formats and repository behavior:
- Templates are stored under `templates/*.md`.
- Notes are stored under `notes/<category-tree>/*.md`.
- Note image imports are stored under `assets/<sanitized-note-title>/<timestamp>_<sanitized-name>`.
- Soft-deleted items are moved under `trash/` and indexed in `.organote/trash.json`.
- Categories with colors are indexed in `.organote/categories.json`.
- Backup/restore ZIP preserves `templates/`, `notes/`, `assets/`, `trash/`, and `.organote/`.

Frontend request responses:
- Package request: `google_fonts`, `emoji_picker_flutter`, `gpt_markdown`, and `loading_animation_widget` are already present in `pubspec.yaml`; no removal needed.
- State management: `flutter_riverpod` is the app-level state system. The old direct `provider` dependency has been removed from `pubspec.yaml`; any remaining lockfile entry is transitive only.
- Raw source: implemented `NoteRepository.getRawSource(String id)`.
- Asset display: implemented `AssetRepository.readAssetBytes(String relativePath)` returning `Uint8List`; paths must stay under `assets/`.
- Pin/favorite: implemented `NoteRepository.setPinned(...)` and `setFavorite(...)`.
- Trash list: added `LibrarySnapshot.trash` and `NoteRepository.watchTrash()`.
- Sync gesture safety: `syncNow()` is safe for direct gestures and uses a sequential lock. Focus debounce should call a separate wrapper on the frontend.
- Theme settings: keep `organote.ui.*` frontend-local for now. Backend will not introduce a settings repository until there is a cross-layer setting.
- Hijri/date convention: keep dual-date markdown display as `01-01-2000 | 24-09-1420 H`; frontend should use `HijriCalendar` from the `hijri` package for conversion.
- Soft delete: `softDeleteNote(id)` is idempotent for missing/already-removed notes and emits through the library/trash streams after completion. Storage failures can still throw and should be surfaced as generic action failure if awaited.

Sync status:
- Google Drive sign-in is wired with `google_sign_in` 7.x and official Google APIs.
- The 6-state reconciler is implemented and unit tested in `lib/services/sync/sync_reconciler.dart`.
- Sync ledger persistence is implemented at `.organote/sync_ledger.json`.
- Google Drive upload/download/delete execution is behind `RemoteFileProvider` and implemented by `GoogleDriveRemoteFileProvider` using Drive file app properties for relative paths and soft-delete flags.

Before changing any expected model shape, write the request in `front_to_backend.md`. Backend will check that file frequently and respond here.
