# Organote Backend Implementation Plan

## Summary
Create the Flutter app scaffold first, then implement Organote's backend as a local-first Dart/Flutter data layer over real markdown files, assets, settings, compliance checks, trash, backup/restore, and Google Drive sync.

Use the `flutter-apply-architecture-best-practices` structure: UI owns `lib/ui/**`; backend owns `lib/domain/**`, `lib/data/**`, `lib/services/**`, dependency setup, and test fixtures. Check `front_to_backend.md` before each backend work session and update `back_to_frontend.md` whenever contracts change.

## Key Changes
- Scaffold a Flutter project targeting Android and Web, with backend-first folders for domain models, repositories, services, use cases, and DI.
- Implement canonical domain models for `Template`, `TemplateField`, `Note`, `NoteRecord`, `Category`, `AssetRef`, `ComplianceIssue`, `TrashEntry`, `SyncLedgerEntry`, `AppSettings`, and `SyncStatus`.
- Use real markdown files as the source of truth:
  - `templates/`, `notes/<category-tree>/`, `assets/<sanitized-note-title>/`, `trash/`.
  - Serialize human-readable markdown using headings and list key-value rows, with a strict metadata block.
  - Parse and write through a single `MarkdownCodec`; frontend must never hand-edit storage strings except through raw source editor APIs.
- Implement platform storage behind one `FileStore` interface:
  - Android/native: `dart:io`, `path_provider`, `file_picker`.
  - Web: strict real-file mode using JS interop around `window.showDirectoryPicker`, `FileSystemDirectoryHandle`, `FileSystemFileHandle`, and writable streams. No IndexedDB primary store.
  - If File System Access API is unavailable or not granted, backend returns `StorageUnavailable` and frontend blocks setup with a clear browser/support message.
- Implement repositories and streams:
  - `LibraryRepository.watchLibrary()` emits notes, templates, categories, tags, compliance counts, and sync status.
  - CRUD commands cover note/template/category create, save, move, rename, pin/favorite, soft-delete, restore, purge, backup ZIP, and restore ZIP.
  - Every disk/cloud save invalidates in-memory caches and emits a reload event to avoid stale list/view data.
- Implement validation/compliance:
  - Validate all field types from `plan.md`: text, number, date, boolean, dropdown, password, URL, IP, regex, image, custom label.
  - Template edits never mutate notes automatically.
  - Compliance scans report missing required fields, type mismatches, version drift, orphan template refs, and rename-copy suggestions.
- Implement sync:
  - Google Drive provider using official `googleapis`, `googleapis_auth`, `google_sign_in`, and `extension_google_sign_in_as_googleapis_auth`.
  - Persistent sync ledger stores local checksum, remote modified time, local sync time, remote file id, and soft-delete state.
  - Use the 6-state reconciliation algorithm from `plan.md`, remote-clock Last-Write-Wins, zombie trash interception, asset dependency filtering, focus debounce, and a sequential push lock.
- Recommended core packages: `provider`, `get_it`, `path_provider`, `shared_preferences`, `file_picker`, `yaml`, `crypto`, `archive`, Google API packages, `hijri`, and app UI packages already chosen by the frontend plan.

## Public Backend Contract For Frontend
Backend owns app scaffold, domain/data/services, storage, parsing, sync, compliance, backup, and DI. Frontend owns `lib/ui/**` and should consume only repository/view-model contracts.

Frontend must not parse markdown directly except for raw source preview/editor. Use:
- `LibraryRepository.watchLibrary()` for Home/Templates/Settings data.
- `NoteRepository.getNote(id)`, `saveStructuredNote(input)`, `saveRawSource(id, source)`, `softDeleteNote(id)`.
- `TemplateRepository.saveTemplate(input)` and `ComplianceRepository.watchComplianceSummary()`.
- `AssetRepository.importImageForNote(...)` for image fields.
- `SyncRepository.signInGoogleDrive()`, `syncNow()`, `watchSyncStatus()`.

Web storage is strict real-file mode. Setup must call backend directory picker from a direct user gesture. If unavailable, show a browser support blocker.

Before changing any expected model shape, write the request in `front_to_backend.md`. Backend will check that file frequently and respond in `back_to_frontend.md`.

## Test Plan
- Unit test markdown parsing/serialization round trips for templates, notes, multi-record notes, metadata, tags, custom labels, raw body, and malformed files.
- Unit test validators for required fields, number length/range, URL, IP, regex, dropdown, image refs, Gregorian/Hijri/dual date storage.
- Unit test filesystem behavior: scaffold directories, sanitize filenames, collision suffixes, category moves, image import paths, soft delete/restore/purge, ZIP export/import.
- Unit test compliance scans against template version drift, missing fields, renamed fields, type changes, and ignore decisions.
- Unit test sync reconciliation with fake local/remote manifests for all 6 states, conflicts, zombie exception, asset filtering, debounce, and sequential lock.
- Add integration tests for startup setup, create template, create multi-record note, edit note, raw source edit, delete/restore, backup/restore, and web storage unsupported path.

## Assumptions And References
- User selected: create the Flutter scaffold first; web must use real files only via JS interop.
- `front_to_backend.md` does not exist yet, so backend starts the coordination protocol by creating `back_to_frontend.md`.
- Web File System Access requires secure context, user permission, and user activation; unsupported browsers are blocked, not silently downgraded.
- References: Dart JS interop docs https://dart.dev/interop/js-interop, `dart:js_interop` API https://api.dart.dev/dart-js_interop/, MDN `showDirectoryPicker()` https://developer.mozilla.org/en-US/docs/Web/API/Window/showDirectoryPicker, MDN File System API https://developer.mozilla.org/en-US/docs/Web/API/File_System_API.
