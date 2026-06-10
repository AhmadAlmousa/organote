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

Compliance ignore persistence:
- `ComplianceRepository.ignoreIssue(String issueId)` and `restoreIgnoredIssue(String issueId)` are implemented. Calls write `.organote/compliance_ignores.json` and trigger a reload so `watchComplianceSummary()` / `scanNow()` immediately reflect the change.
- Ignored issues still appear in `ComplianceSummary.issues` with `ignored: true`; `activeCount` and `errorCount` already exclude them. The frontend's session-local set in Phase 9 can be replaced by these calls.
- Issue IDs are stable across scans as long as `note.id`, `record.label`, and `field.id` do not change. Renaming or recreating a record/field invalidates the persisted id (the warning will re-surface), which is the intended semantics.

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
- The 6-state reconciler is implemented and unit tested in `lib/services/sync/sync_reconciler.dart`. Coverage now includes one test per branch (remote new, local new, unchanged, local-only change, remote-only change, conflict download-winner, conflict upload-winner, local deletion, remote deletion, prune-everywhere) plus the remote soft-delete flag (with and without a local file), the zombie exception, asset filtering (referenced vs unreferenced, plus the initial-sync empty-set passthrough), and deterministic path ordering.
- `GoogleDriveSyncRepository` is exercised end-to-end against a fake `RemoteFileProvider` and the in-memory file store: upload, download, push-soft-delete on local deletion, delete-local on remote deletion, zombie interception against the persisted trash index, remote-clock conflict resolution, the sequential lock that collapses concurrent `syncNow()` calls into a single execution, the scanning → syncing → complete status sequence, and the not-connected error path.
- Sync ledger persistence is implemented at `.organote/sync_ledger.json`.
- Google Drive upload/download/delete execution is behind `RemoteFileProvider` and implemented by `GoogleDriveRemoteFileProvider` using Drive file app properties for relative paths and soft-delete flags.

Active handoff: Web Google Sign-In cross-origin issue (2026-05-29):
- User still reports a browser cross-origin / COOP console error during web
  sign-in, so this is not resolved yet.
- The first attempted fix was to stop treating web sign-in as one direct
  `authenticate()` call. The web flow now expects the Google-rendered identity
  button first, then the app's Drive authorization action for the `drive.file`
  scope.
- `google_sign_in_web ^1.1.3` was added. `lib/ui/widgets/google_sign_in_web_button_web.dart`
  renders `google_sign_in_web/web_only.dart`'s `renderButton`, and
  `settings_screen.dart` shows that button above the Drive row on web when the
  sync status is not signed in.
- `SyncRepository.prepareGoogleDriveSignIn()` was added and Settings calls it
  after the first frame on web. This initializes `GoogleSignIn` and subscribes
  to `authenticationEvents` before the web button is used.
- `GoogleDriveSyncRepository` now stores the
  `GoogleSignInAuthenticationEventSignIn.user` in `_webAccount`. On web,
  `signInGoogleDrive()` requires that account and calls
  `account.authorizationClient.authorizationForScopes(scopes)` or
  `authorizeScopes(scopes)` to grant Drive access.
- The web client ID is read from
  `<meta name="google-signin-client_id" content="...">` via
  `google_sign_in_web_config_web.dart`, with placeholder values ignored. The
  current `web/index.html` contains a concrete Web OAuth client ID.
- The web canceled-popup error text was changed to point at popup blockers and
  OAuth web origins instead of Android SHA-1 setup.
- `tools/serve_web.py` was added for local/release web testing. It serves the
  Flutter bundle with `Cross-Origin-Opener-Policy: same-origin-allow-popups`
  and `Referrer-Policy: strict-origin-when-cross-origin`. `README.md` now says
  to use this server instead of plain `python3 -m http.server` for Drive sync
  testing and to verify the tunneled response with
  `curl -I https://dev2.tnl.almou.sa/`.
- Suspected remaining frontend/deployment checks: confirm the exact console
  message and stack, verify the effective headers on the actual browser origin
  are not stripped or overwritten by the tunnel/reverse proxy, confirm the
  exact origin is present in Google Cloud Console's Authorized JavaScript
  origins, and verify the user is clicking the Google-rendered button before
  the Drive authorization icon.
- Current tests only cover the repository contract shape and fake sync paths;
  they do not validate the real browser popup/GIS flow.

Backend test coverage (124 tests, `flutter analyze` clean):
- Storage helpers: `sanitizeFileName`, `normalizeRelativePath`, `MemoryFileStore` init/ensureStructure idempotency, recursive list/move/delete, and `StorageUnavailableException` before init — `test/services/storage/file_store_test.dart`.
- Repository round-trips: empty-store startup snapshot, multi-record note round trip through `MarkdownCodec` (Person-1/Person-2 + dual hijri date), `saveRawSource` rewriting on disk and throwing `StateError` for unknown ids — `test/data/repositories/local_organote_repository_test.dart`.
- Sync ledger persistence: empty-file passthrough, JSON round trip, stable sort by `relativePath`, full-snapshot overwrite, soft-deleted flag retention, and empty-write producing `[]` — `test/services/sync/sync_ledger_store_test.dart`.
- Backup service: only `templates/`, `notes/`, `assets/`, `trash/`, `.organote/` are archived (other paths skipped), restore writes archived files back, restore overwrites existing target files, and restore still runs `ensureStructure` — `test/services/backup/backup_service_test.dart`.
- Existing coverage carries over: markdown codec round trips, field validators per type, compliance scans (drift/missing/orphan/rename), sync reconciler 6-state matrix, Google Drive sync repository end-to-end against fake remote.

Before changing any expected model shape, write the request in `front_to_backend.md`. Backend will check that file frequently and respond here.

---

## Frontend assignments for sync/storage follow-up (2026-06-02)

User reported web storage re-selection, duplicate web sign-in buttons, Android
sync configuration failure, and the flattened Google Drive folder layout. Backend
requests and technical resolution plan are tracked in `front_to_backend.md`.

Frontend-owned items:

1. **Web storage reconnect UX**
   - Once backend restores persisted File System Access handles, keep the splash
     flow on the library path when `StorageStatus.isAvailable` is true.
   - When backend reports a stored handle that needs permission re-grant, show a
     single gesture-safe "Reconnect folder" action instead of wording that
     implies the user must pick a new storage directory.
   - Settings -> Data should continue to show `StorageStatus.rootLabel`, but the
     action label should distinguish "Change folder" from "Reconnect folder"
     when backend exposes that state.
   - Add/adjust widget coverage for the storage gate labels and disabled
     unsupported-browser path.

2. **Single web Drive connect button**
   - Remove the visible `GoogleSignInWebButton` from Settings once backend makes
     `SyncRepository.signInGoogleDrive()` a direct web authorization flow.
   - Use one primary app control for Drive: "Connect Drive" when disconnected,
     "Sync now" when connected, plus the existing status pill.
   - Avoid in-app instructional text that tells the user to click one sign-in
     button and then another. The flow should be self-contained in the button
     state and toast/status messaging.
   - Update `test/ui/settings_screen_test.dart` so web Settings asserts a single
     Drive connection control is rendered.

3. **Android configuration error messaging**
   - Keep the visible error compact, but map the Android Google Sign-In provider
     configuration failure to copy that names package name, SHA-1, and Web OAuth
     client ID/serverClientId.
   - Do not surface the raw `[28444] Developer console is not setup correctly`
     string as the primary message.

4. **Hierarchical Drive mirror status**
   - After backend changes Drive sync from flattened files to hierarchy mirroring,
     Settings -> Sync should keep using `SyncStatus` only; no frontend parsing of
     Drive structure is required.
   - If backend adds sync progress details, render them as concise status text
     under the existing Sync section rather than introducing a new maintenance
     screen.

Frontend should wait for the backend contract changes before deleting
`lib/ui/widgets/google_sign_in_web_button*.dart`; those files are still needed by
the current two-step implementation.

### Implementation status (2026-06-02)

The frontend assignments above are implemented in the current worktree:

- Settings now renders one primary Drive action: `Connect Drive` while
  disconnected, `Sync now` after connection.
- The rendered Google web sign-in button is no longer used by Settings.
- Splash and Settings distinguish saved-folder permission re-grants with
  `Reconnect folder`.
- Android setup errors are compacted to actionable OAuth setup checks.
- Follow-up after user retest: the web entry point unregisters old Flutter
  service workers before bootstrapping the app, preventing stale cached bundles
  from showing the previous two-button Drive UI.

The `google_sign_in_web_button*.dart` files have been removed; Settings now owns
the single visible Drive action.

### Sync overwrite warning contract (2026-06-02)

`SyncRepository` now exposes `previewRemoteOverwrites()`, returning
`SyncOverwriteWarning` entries for note/template files where the next sync plan
would download the Drive version over an existing local file. Each warning
includes the relative path, item type, local modified time, remote modified time,
and derived newer side. Settings calls this immediately after Drive sign-in and
shows the warning dialog before any sync write occurs.

Frontend design notes for the warning popup:

- The dialog should feel like a focused risk review, not a generic alert. Keep
  the title direct: remote Drive changes will replace local files on the next
  sync.
- Show one row per affected note/template with the relative path, a note/template
  icon, local modified time, Drive modified time, and a compact status pill:
  `Drive newer`, `Local newer`, or `Same time`.
- Include templates with the same visual weight as notes. This warning is not
  note-only.
- Keep the list scrollable and capped visually so many conflicts do not overflow
  mobile or desktop dialogs. Summarize hidden rows as `+N more affected files`.
- Do not start sync from this dialog. It is informational after sign-in; the
  existing `Sync now` action remains the user-controlled write step.
- If the preview scan fails after sign-in, keep Drive connected and show a
  compact toast that the overwrite check failed instead of treating sign-in as
  failed.
- Verify on compact mobile and wide desktop that long paths and timestamps
  truncate cleanly, status pills do not overlap, and the dialog actions remain
  reachable.
