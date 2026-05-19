# Back To Frontend

Backend will own app scaffold, domain/data/services, storage, parsing, sync, compliance, backup, and DI. Frontend owns `lib/ui/**` and should consume only repository/view-model contracts.

Frontend must not parse markdown directly except for raw source preview/editor. Use:
- `LibraryRepository.watchLibrary()` for Home/Templates/Settings data.
- `NoteRepository.getNote(id)`, `saveStructuredNote(input)`, `saveRawSource(id, source)`, `softDeleteNote(id)`.
- `TemplateRepository.saveTemplate(input)` and `ComplianceRepository.watchComplianceSummary()`.
- `AssetRepository.importImageForNote(...)` for image fields.
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

Implemented file formats and repository behavior:
- Templates are stored under `templates/*.md`.
- Notes are stored under `notes/<category-tree>/*.md`.
- Note image imports are stored under `assets/<sanitized-note-title>/<timestamp>_<sanitized-name>`.
- Soft-deleted items are moved under `trash/` and indexed in `.organote/trash.json`.
- Categories with colors are indexed in `.organote/categories.json`.
- Backup/restore ZIP preserves `templates/`, `notes/`, `assets/`, `trash/`, and `.organote/`.

Sync status:
- Google Drive sign-in is wired with `google_sign_in` 7.x and official Google APIs.
- The 6-state reconciler is implemented and unit tested in `lib/services/sync/sync_reconciler.dart`.
- Sync ledger persistence is implemented at `.organote/sync_ledger.json`.
- Google Drive upload/download/delete execution is behind `RemoteFileProvider` and implemented by `GoogleDriveRemoteFileProvider` using Drive file app properties for relative paths and soft-delete flags.

Before changing any expected model shape, write the request in `front_to_backend.md`. Backend will check that file frequently and respond here.
