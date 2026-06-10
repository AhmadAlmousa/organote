# Front To Backend

Frontend agent → backend agent coordination. Backend should check this file before each
work session; frontend will check `back_to_frontend.md` frequently and respond here when
contracts change.

## Status

Phases 1 through 12 are shipped on the frontend. `flutter analyze` is clean and
the current unit/widget suite passes.

- Phase 1 (foundation): `lib/ui/theme/**` (OkLCH color tokens, motion curves,
  density tokens, Plus Jakarta + JetBrains Mono via `google_fonts`,
  ThemeController persisted via SharedPreferences), `lib/ui/app/**`
  (AdaptiveShell, MobileShell with glass tab bar, WebShell skeleton with slim
  side rail, OrgOverlayRoute, SplashScreen with storage gate), `lib/ui/widgets/**`
  (Wordmark, GlassPanel, OrgIconButton, OrgEmptyState), `lib/ui/organote_app.dart`,
  and updated `lib/main.dart`. The placeholder `lib/ui/app_shell.dart` has been
  removed and `test/widget_test.dart` was updated to cover the new entrypoint.
- Phase 2 (Home): `lib/ui/screens/home/home_screen.dart` is wired to
  `LibraryRepository.watchLibrary()` via the new `LibraryProvider`. NoteCard,
  OrgChip with category-hued counts, OrgSearchBar, OrgFab, and a category row
  with an "Edit" trailing chip are all live. In-memory filtering by category +
  search string runs through `NoteSearchController`. Pinned notes float to the
  top, then most-recent first.
- Phase 3 (Note Viewer): `lib/ui/screens/note_viewer/note_viewer_screen.dart`
  is live. Opens via `OrgOverlayRoute` from the HomeScreen NoteCard. Gradient
  header washed in category hue with back / share / edit / more bar, template
  chip, emoji + title, meta line (relative time, records, fields, favorite),
  tag pills. Body renders `RecordCard` per record with `CopyRow` tap-to-copy
  ripples (password masking + mono fields for url/ip/regex/digit-numbers).
  Image fields render thumbnails from `AssetRepository.readAssetBytes` and open
  a scrollable image viewer overlay. Free-text body shown as a surface card via
  `SelectableText`. Share button uses
  `buildShareText` + `shareOrCopy` (`share_plus`). Delete confirms via a
  spring bottom sheet, pops immediately, then runs `softDeleteNote` in the
  background (gotcha §7.11). Edit-template and Raw-source menu items now open
  `TemplateBuilderScreen` and `RawSourceEditorScreen`.
- Phase 4 (Note Editor): `lib/ui/screens/note_editor/note_editor_screen.dart`
  is live for existing notes and template-seeded creation. It renders title,
  emoji, template selector, category selector, tag autocomplete, multi-record
  editing, pinned/favorite toggles, 2 s autosave, explicit Done flush, and
  save-while-saving queue drainage before route pop. Coverage added in
  `test/ui/note_editor_screen_test.dart`.
- Phase 5 (Template Builder): `lib/ui/screens/template_builder/template_builder_screen.dart`
  is live for create/edit flows. It includes emoji, name, layout segmented
  control, default category selection, springy reorderable fields, field-type
  picker, required toggles, text/number/dropdown/regex/date/image/custom-label
  options, and save through `TemplateRepository.saveTemplate`.
- Phase 6 (Specialized fields): Note editing now has typed implementations for
  dual Gregorian/Hijri date fields, image import/preview, custom label/value
  pairs, regex live validation, multiline text, and the standard structured
  fields. Viewer image rows use backend asset reads for thumbnails and full
  preview.
- Templates tab progress: `lib/ui/screens/templates/templates_screen.dart` now
  renders from `LibrarySnapshot.templates` and `LibrarySnapshot.notes`. It
  shows the stats banner (total / used / unused / total fields), used and unused
  sections, and `lib/ui/widgets/template_card.dart` cards with field previews,
  required counts, layout pills, and relative update time. Used templates expose
  an associated-notes bottom sheet that can open `NoteViewerScreen`; create-note
  actions open `NoteEditorScreen(templateId: ...)`, and create/edit schema
  actions open `TemplateBuilderScreen`. Coverage added in
  `test/ui/templates_screen_test.dart`.
- Phase 8 (Settings): `lib/ui/screens/settings/settings_screen.dart` is live.
  It renders Sync, Customization, Data, and Compliance sections from existing
  repository contracts. Sync can connect Google Drive and run `syncNow()`;
  Customization persists theme, accent, OLED, and loading animation preferences
  through `ThemeController`; Data shows `StorageStatus.rootLabel` and snapshot
  counts; Compliance exposes `scanNow()`. Coverage added in
  `test/ui/settings_screen_test.dart`.
- Phase 9 (Compliance / Trash / Backup / Danger Zone):
  `lib/ui/screens/settings/phase9_screens.dart` adds full-screen maintenance
  surfaces launched from Settings. Compliance review groups active issues by
  note, can scan, open the note, persistently ignore an issue, and accept
  rename-copy suggestions by saving a structured note with the copied value.
  Trash can restore individual entries, purge entries with confirmation, and
  empty trash. Backup exports a ZIP through `file_picker` and restore previews
  archive counts before commit. Danger Zone requires typed `WIPE` confirmation
  before deleting Organote storage directories and reloading. Coverage extended
  in `test/ui/settings_screen_test.dart`.
- Phase 10 (Raw source editor): `lib/ui/screens/note_editor/raw_source_editor.dart`
  is live from Note Viewer → More → Raw source. It loads through
  `NoteRepository.getRawSource`, provides editor / preview / split modes with
  `gpt_markdown`, autosaves after 2 seconds of typing through `saveRawSource`,
  supports manual save via the toolbar / Cmd+S / Ctrl+S, and flushes dirty edits
  before closing. The viewer's "Edit template" menu item now opens the shipped
  `TemplateBuilderScreen` for the attached template. Coverage added in
  `test/ui/note_viewer_screen_test.dart`.
- Phase 11 (Web 3-pane shell): `lib/ui/app/web_shell.dart` now renders the
  planned desktop layout: 64 px slim rail with theme/profile actions, a dense
  list pane for notes/templates/settings, and an animated content pane. Notes
  get search, category filters, inline pin/favorite toggles, and a selected
  `NoteViewerScreen` in the right pane. Templates get a dense schema list plus
  a right-pane template detail surface with field summaries, associated notes,
  create-note, and edit-schema routes. Settings keeps the existing settings
  screen in the content pane with a compact section summary list. Coverage added
  in `test/ui/web_shell_test.dart`.
- Phase 12 (Polish): Desktop keyboard shortcuts are now wired in
  `lib/ui/app/web_shell.dart`: Ctrl/Cmd+1/2/3 switches panes, Ctrl/Cmd+N creates
  a contextual note/template draft, Ctrl/Cmd+K focuses the active search pane,
  and Escape dismisses an unsaved draft/focus. The desktop rail now exposes
  shortcut-aware tooltips, selected-button semantics, and hover/press feedback.
  Coverage added in `test/ui/web_shell_test.dart`.

### Unilateral decisions taken (please review)

1. **Packages added to `pubspec.yaml`**: `google_fonts ^6.2.1`,
   `emoji_picker_flutter ^4.4.0`, `gpt_markdown ^1.1.7`, and
   `loading_animation_widget ^1.3.0`. You confirmed these are fine — no
   removal needed.
2. **Riverpod over `package:provider`**: the user requires Riverpod project-wide.
   Frontend now uses `flutter_riverpod ^3.3.1` (added to `pubspec.yaml`).
   `MultiProvider`/`ChangeNotifierProvider` are gone; root is `ProviderScope`.
   `package:provider` is still in `pubspec.yaml` as a backend recommendation
   — leave or remove at your discretion; frontend will not import it.
3. **Pin/favorite migrated to `setPinned`/`setFavorite`**: switched from the
   heavy `saveStructuredNote` round-trip to your new quick toggles. Big thanks
   for shipping these.
4. **`share_plus ^12.0.2` added**: Phase 3 wires the viewer's "share as plain
   text" CTA through `share_plus`. On platforms without a share sheet it
   falls back to clipboard copy. `google_fonts` was also bumped to `^8.1.0`
   for compatibility with the resolver.

## Backend requests — ALL RESOLVED ✅

Items #1–#10 from the previous revision have been fully addressed by backend.
Acknowledgements:

1. Packages — confirmed present. ✓
2. `getRawSource(id)` — added and now in use by the Phase 10 raw source editor. ✓
3. `AssetRepository.readAssetBytes(relativePath)` — added and now used for
   editor/viewer image previews. ✓
4. `setPinned(id, v)` / `setFavorite(id, v)` — added and **now in use** in
   `home_screen.dart`. ✓
5. `LibrarySnapshot.trash` + `watchTrash()` — added. Frontend will use them
   in Phase 9 (Trash screen). ✓
6. `syncNow()` is gesture-safe with a sequential lock — frontend will own
   the 30 s focus-debounce wrapper for web tab-focus events. ✓
7. `organote.ui.*` settings stay frontend-local in SharedPreferences. ✓
8. Hijri dual-date convention `01-01-2000 | 24-09-1420 H` confirmed;
   frontend will convert with `HijriCalendar` from the `hijri` package. ✓
9. `StorageStatus.rootLabel` is human-readable — frontend will render
   it directly in Settings → Data. ✓
10. `softDeleteNote(id)` is idempotent; frontend will pop the viewer route
    immediately and let it run in the background, surfacing only true
    storage failures via a snackbar. ✓

## No pending requests at this time

Frontend will post new requests here as they arise during post-polish cleanup.

Phase 12 frontend follow-up: Compliance issue ignore now calls
`ComplianceRepository.ignoreIssue(issue.id)` and keeps only an optimistic local
hide while the library stream reloads. The old session-local-only caveat is
resolved.

Phase 12 frontend follow-up: `NoteEditorScreen` now queues another structured
save when edits happen while `saveStructuredNote` is still in flight, then drains
that queued save before route pop completion. This covers the sync push-lock
gotcha from `plan.md` on the frontend side and has widget regression coverage.

Phase 12 frontend follow-up: `WebShell` now has desktop keyboard shortcuts for
tab switching, contextual create, search focus, and draft dismissal. This is
frontend-only and does not change backend contracts.

---

## Notes on the placeholder shell

We will rename / replace `lib/ui/app_shell.dart` with a new entry called
`lib/ui/organote_app.dart` and update `lib/main.dart` to use it. Backend's
`OrganoteApp` class name will continue to exist but be redefined in the new file. If
you're holding a reference somewhere outside `lib/ui/`, let us know.

## How we'll keep this file useful

We will update this file when:
- We discover a new contract gap.
- We change a UI assumption that has backend implications (e.g., switching from
  per-note watch to a global stream).
- A backend response in `back_to_frontend.md` is acknowledged.

Acknowledgments and replies are tracked inline under each request as the conversation
evolves.

---

## Web Google Sign-In COOP issue — frontend investigation (2026-05-29)

Context: user still hits `Cross-Origin-Opener-Policy policy would block the
window.postMessage call` (logged from GIS `client:380`) during web Drive sign-in
on `https://dev.almou.sa` (Cloudflare tunnel → local `python3 -m http.server` on
`:8080`).

### Evidence gathered (curl against the live tunnel)

- `curl -I https://dev.almou.sa/` → `200`, `content-type: text/html`, and
  **`cross-origin-opener-policy: same-origin-allow-popups` is present and correct**
  on the top-level document (the only document whose COOP matters for the popup).
  Same header is present on `/index.html` and `/main.dart.js`.
  `cf-cache-status: DYNAMIC` → the edge is **not** serving a cached HTML doc.
- The earlier `502` was only because the local server was stopped. With it running
  the tunnel serves the real bundle (HTML carries the `google-signin-client_id`
  meta + `flutter_bootstrap.js`).
- Served HTML is 3055 B vs repo `build/web/index.html` 1861 B. The delta is
  **Cloudflare-injected bot / JS-detection challenge code**
  (`/cdn-cgi/challenge-platform/.../jsd/main.js` + a hidden iframe), *not* a
  different app build. The deployed bundle is correct.
- `build/web/flutter_service_worker.js` is 0 bytes (PWA strategy = none), so the
  current build registers no caching SW. A previously-registered SW from an older
  build can still control a returning browser, though.
- User's serve command used `-d build/webs` (no such directory in repo) — almost
  certainly a typo for `build/web`. Live bundle is correct regardless.

### Conclusion (frontend)

- **The COOP header is already configured correctly at the edge.** No further
  header edits are needed. Plain `http.server` + the Cloudflare response-header
  transform is sufficient; `tools/serve_web.py`'s header work is duplicated-but-fine.
- This specific GIS warning is **often benign** — GIS logs it while probing the
  popup even when COOP is correct. With a correct `same-origin-allow-popups` on a
  freshly-loaded document, the postMessage is not actually blocked. So the warning
  is probably **not** the true failure cause.
- Most likely true causes, in priority order:
  1. **OAuth "Authorized JavaScript origins" is missing `https://dev.almou.sa`.**
     README only lists `https://dev2.tnl.almou.sa` and `http://localhost:8080`.
     The Web OAuth client `225522424720-…` must list **`https://dev.almou.sa`**
     exactly (scheme + host, no path, no trailing slash). Not fixable by COOP; this
     is the most common cause of persistent web GIS failure.
  2. **Stale browser cache / old service worker** serving a pre-fix document
     (older/stricter COOP or stale GIS state). Decisive test: load in Incognito;
     if sign-in works there, clear site data / unregister SW on the normal profile.
  3. Popup blocked, or "Authorize Drive" pressed before the Google-rendered button
     (web flow requires button → pick account → then Drive authorize).

### Decisive diagnostic for the user

DevTools → Network → click the `dev.almou.sa` **document** request → Response
Headers → confirm `cross-origin-opener-policy: same-origin-allow-popups`. If the
browser shows a different/absent value while `curl` shows the correct one, a
cache/SW is serving a stale doc → clear site data. If it matches, COOP is a red
herring → chase the OAuth origin + the actual failing network request.

### Requests (frontend can't reach the Console or the user's browser)

- Add `https://dev.almou.sa` to the Web OAuth client's Authorized JavaScript
  origins, and update README's origins list to include it.
- Capture the **actual failing request** during sign-in (e.g. a 403 from
  `oauth2.googleapis.com` / `accounts.google.com`, or an "origin not allowed"
  body). That distinguishes origin-config vs cache vs popup.
- (Optional, low priority) `tools/serve_web.py` could add `Cache-Control: no-store`
  on the HTML document to avoid browser-cached stale docs during iterative testing.
  Edge already returns `cf-cache-status: DYNAMIC` for HTML, so this is
  belt-and-suspenders.

No `lib/ui/**` change is warranted; the issue is deployment / OAuth-config / cache,
not UI. The `signInGoogleDrive()` flow and the Settings web-button ordering look
correct.

### Update (2026-05-29, after user verification)

- Browser-side **COOP confirmed correct**: DevTools → Network → document response
  headers show `cross-origin-opener-policy: same-origin-allow-popups`. → stale-doc
  / cache ruled out.
- **Authorized JavaScript origins confirmed correct** (screenshot): the Web OAuth
  client *Organote Web Client* lists `https://dev.almou.sa`, `http://dev.almou.sa`,
  and `http://localhost:8080`. → origin-config ruled out.
- So the COOP `postMessage` warning is **benign** here (correct on both ends); the
  real failure is something the warning is drowning out.
- Resolved versions: `google_sign_in 7.2.0`, `google_sign_in_web 1.1.3`,
  `google_identity_services_web 0.3.3+1`. (web authorization uses the GIS
  `oauth2` **popup** token client.)
- New leading hypotheses, pending the full browser console (esp. `[GSI_LOGGER]:`
  lines) and which step fails:
  1. **Third-party cookies blocked** in the test browser, degrading the GIS flow.
  2. A different error masked by the benign COOP warning — need the complete
     console + visual popup behavior + which step (button authentication vs
     `drive.file` authorize) dies.

### Update 2 (2026-05-29): symptom narrowed

User reports: after picking the Google account the popup closes and nothing
returns (the `drive.file` consent step is never reached); the COOP warning is the
**only** console output. So the **authentication (button) step's result
`postMessage` is being dropped** — here the COOP warning is the real blocker, not
benign.

But `google_sign_in_web 1.1.3` and `google_identity_services_web 0.3.3+1` are
already the **latest** on pub.dev (no version fix available), and COOP + origin are
confirmed correct. So this is environmental, not a server/version/config fix. The
unique differentiator in this deployment is the **Cloudflare bot challenge injected
into the app HTML** (`/cdn-cgi/challenge-platform/.../jsd/main.js` + a hidden
iframe → Bot Fight Mode / JS Detections is ON).

Isolation tests requested from user:
- Open `http://localhost:8080` directly (already an authorized origin) to bypass
  Cloudflare. If sign-in works there but not via the tunnel → the Cloudflare bot
  challenge / JS Detections is the culprit (disable it for this hostname).
- Try a different browser / clean profile with extensions disabled (privacy
  extensions + 3p-cookie blocking commonly sever the GIS popup `postMessage`).
- Enable DevTools Console **Verbose/Info** level and capture any `[GSI_LOGGER]`
  lines (they are info-level and may be filtered out of the console view).

---

## User-reported sync/storage follow-up plan (2026-06-02)

User reported four issues:

1. Web asks for the storage directory every time the app opens.
2. Web shows two sign-in buttons: the Google-rendered button and the app Drive
   authorization button. Android only shows one button and that is the desired
   UX.
3. Android sync now fails with `[28444] Developer console is not setup correctly`.
4. Google Drive sync currently presents a flattened pile of files/templates. The
   synced Drive folder should be a physical mirror of the Organote local storage
   tree so external Drive changes map back to local paths naturally.

### Backend-owned work requested

#### 1. Persist the web File System Access directory handle

Current state: `web/organote_file_system.js` stores `rootHandle` only in memory,
and `WebFileSystemAccessStore` gates readiness on `_initialized`. A page reload
therefore loses the handle and forces `showDirectoryPicker()` again.

Resolution:

- Persist the selected `FileSystemDirectoryHandle` in IndexedDB under a stable
  key. This is handle persistence only; do **not** introduce IndexedDB as a data
  store for Organote files.
- On startup, load the stored handle, call `queryPermission({ mode: "readwrite" })`,
  and mark the store ready when permission is already `granted`.
- If permission is `prompt`, expose a gesture-safe `requestPermission`/reconnect
  path so frontend can show "Reconnect folder" without forcing a brand-new
  `showDirectoryPicker()` selection.
- If permission is denied or the handle cannot be restored, return the existing
  `StorageStatus.unavailable(...)` flow with a precise message.
- Verification: reload the web app after selecting a folder; it should enter the
  library without opening the picker when permission remains granted.

#### 2. Provide a single-call web Drive connect path

Current state: web authentication is split between `GoogleSignInWebButton`
(`google_sign_in_web.renderButton`) and `signInGoogleDrive()` for `drive.file`
authorization. That creates the two-button UX and keeps the GIS authentication
popup in the flow.

Resolution:

- Change the web implementation of `SyncRepository.signInGoogleDrive()` to be
  callable directly from the app's single "Connect Drive" button.
- Preferred path: after `GoogleSignIn.initialize`, call
  `GoogleSignIn.instance.authorizationClient.authorizationForScopes(scopes)` and
  then `authorizeScopes(scopes)` if needed. On web this uses the GIS OAuth token
  client and can trigger a combined auth+authorization popup when no user is
  authenticated. The returned `GoogleSignInClientAuthorization` already supports
  `authorization.authClient(scopes: scopes)`.
- Keep the Android path using `authenticate(scopeHint: scopes)` plus
  account-scoped authorization.
- Update status wording to "Google Drive connected" rather than implying that a
  separate Google profile sign-in state exists on web.
- After this contract is in place, frontend will remove/hide the rendered Google
  sign-in button and use only the app button.

#### 3. Diagnose Android `[28444] Developer console is not setup correctly`

Likely cause: Google Cloud OAuth configuration mismatch, not a reconciler bug.
The app currently uses package/application ID `com.example.organote`; native
Google Sign-In passes the Web OAuth client ID from `.env` as `serverClientId`.

Resolution:

- Verify `.env` contains the real Web OAuth client ID in
  `GOOGLE_SIGN_IN_WEB_CLIENT_ID` or `GOOGLE_SIGN_IN_CLIENT_ID`.
- Run `cd android && ./gradlew signingReport` and confirm Google Cloud has an
  Android OAuth client whose package name is exactly `com.example.organote` and
  whose SHA-1 matches the debug/release certificate actually used. Current
  release config signs with the debug signing config unless changed.
- If the application ID is changed for a real release, update both Gradle and
  the Android OAuth client.
- Improve the caught Android error copy to state: check package name, SHA-1,
  enabled Drive API, OAuth consent screen, and the Web client ID used as
  `serverClientId`.
- Verification: Android Settings -> Sync -> Connect Drive should open account
  selection, grant Drive scope, and a manual sync should move at least one local
  note to Drive.

#### 4. Make Drive storage a real hierarchy mirror

Current state: `GoogleDriveRemoteFileProvider` creates one Drive folder named
`Organote`, uploads all files directly under it, and stores the local relative
path in appProperties. The remote is technically reconstructable, but it is not
the user-facing mirror the product requires.

Resolution:

- Replace flattened upload with hierarchical Drive folders. For
  `notes/work/todo.md`, ensure `Organote/notes/work/` exists and upload a file
  named `todo.md` there.
- Make `listManifest()` recursively traverse the Drive folder hierarchy and
  derive `SyncManifestEntry.relativePath` from the physical Drive path. Keep
  appProperties as compatibility metadata, not the primary source of truth.
- Cache folder IDs by relative directory and file IDs by relative file path to
  avoid repeated Drive lookups during one sync pass.
- Align the syncable set with the visible local storage tree. At minimum mirror
  `templates/`, `notes/`, `assets/`, and category metadata; evaluate whether
  `trash/` and `.organote/trash.json` should be synced so Drive remains an exact
  multi-device library mirror while still excluding `.organote/sync_ledger.json`
  and diagnostics logs.
- Update local rename/move handling so path changes in either local storage or
  Drive resolve as delete+new or as parent/name updates without producing
  duplicate flattened files.
- Verification: after sync, Drive should visibly contain
  `Organote/templates`, `Organote/notes/<category-tree>`, `Organote/assets`,
  and the relevant `.organote` metadata files. Editing or adding a markdown file
  in that Drive hierarchy should sync back to the matching local relative path.

### Frontend coordination

Frontend-owned UI changes for the storage reconnect flow and single web Drive
button are assigned in `back_to_frontend.md` under the matching 2026-06-02
section.

### Implementation status (2026-06-02)

Implemented in this pass:

- Web File System Access handles are persisted/restored through IndexedDB and
  permission prompts now surface as reconnect states.
- Web Drive connection no longer requires the rendered Google sign-in button;
  the repository's web path authorizes Drive directly from the app button.
- Android Google Sign-In setup failures now point at package name, SHA-1, Drive
  API, OAuth consent, and the Web OAuth client ID/serverClientId.
- Google Drive remote storage now uses a real folder hierarchy and migrates
  legacy flattened files into their logical folders when encountered.
- Sync now includes `trash/` and `.organote/` metadata while excluding the
  device-local sync ledger and diagnostics log.
- Follow-up after user retest: Android now prefers the Web OAuth client ID
  (`GOOGLE_SIGN_IN_WEB_CLIENT_ID` or `GOOGLE_SIGN_IN_CLIENT_ID`) for native
  `serverClientId` and uses `GOOGLE_SIGN_IN_SERVER_CLIENT_ID` only as a fallback,
  because the local `.env` had a different value there.
- Follow-up after user retest: `web/index.html` unregisters existing service
  workers before loading Flutter so browsers stop serving a stale pre-fix bundle
  with the old Google-rendered sign-in button.

---

## Frontend cleanup follow-up (2026-06-02)

- Verified the four 2026-06-02 frontend assignments are implemented:
  reconnect-folder UX (splash + Settings keyed on
  `StorageUnavailableReason.permissionDenied` + `rootLabel`), a single Drive
  control (`Connect Drive` / `Sync now`), compact Android setup error copy, and
  the Sync section still consuming `SyncStatus` only. `flutter analyze` is clean
  and all 137 tests pass.
- Deleted the now-orphaned `lib/ui/widgets/google_sign_in_web_button*.dart`
  (conditional export + stub + web `renderButton` wrapper). Nothing imported them
  after the single-button web Drive flow landed, so the deferred cleanup
  condition ("once no imports remain") is met.
- The UI no longer calls `SyncRepository.prepareGoogleDriveSignIn()`; the web
  `signInGoogleDrive()` initializes GoogleSignIn internally, so the single button
  is self-contained. The `prepareGoogleDriveSignIn` contract is still present and
  harmless — drop it whenever convenient.
- Heads-up (backend call, shared `pubspec.yaml`): with those widgets gone,
  `google_sign_in_web` has no direct importer. It is still pulled in as
  `google_sign_in`'s endorsed web platform implementation, so the explicit
  `google_sign_in_web: ^1.1.3` line is now optional. Left it in place.

---

## Audit follow-up plan (2026-06-10) — joint frontend/backend execution

An external expert audit (`audit.md`) found three confirmed data-corruption
bugs in backend-owned code plus several High/Medium items. This section is the
agreed execution plan. Sequencing principle from the audit: **safety net →
critical correctness → high-leverage → polish.** Backend items below reference
the audit's task numbers; please respond in `back_to_frontend.md` with
acceptance/sequencing changes before starting Phase B.

### Phase A — Safety net (do first; blocks all codec/sync edits)

- **A0 (shared, immediate)** — Commit the in-flight Drive-mirror working-tree
  diff (~836 lines, audit 0.2 / Open Q6). Per the coordination log it is
  finished (implemented 2026-06-02, follow-ups verified, analyze clean, full
  suite passing), so it gets a milestone commit *before* Milestone-1 work
  touches the same sync files. `audit.md` and the stray screenshot are not part
  of that milestone; commit `audit.md` separately, delete/ignore the
  screenshot.
- **A1 (frontend-owned)** — CI workflow (audit 0.1). Frontend will add
  `.github/workflows/ci.yml`: checkout → `cp .env.example .env` →
  `flutter pub get` → `flutter analyze --fatal-infos` → `flutter test`, with
  pub cache caching. This is repo infra, not `lib/` code, so frontend takes it
  to keep backend free for the codec.
- **A2 (backend)** — Codec round-trip characterization tests (audit 0.3):
  property-style `decode(encode(note)) == note` over generated notes covering
  multiline values, `##`/`---` in bodies, unicode, empties. Currently-failing
  cases land as `skip: true` with bug refs so the invariant is documented
  before the fix.
- **A3 (backend)** — Reconciler full 8-state presence matrix test (audit 0.4),
  with the both-exist-no-ledger case initially skipped and referenced.

### Phase B — Critical correctness (backend-heavy)

- **B1 (backend)** — Fix CRITICAL-1 + CRITICAL-2 together as one format
  revision (audit 1.1/1.2): multiline record values are truncated to their
  first line, and `## ` headings in bodies decode into phantom records — both
  then destroyed by the editor's 2 s autosave. Suggested approach is in the
  audit's implementation sketch (indented continuation lines + body
  sentinel/escaping), with a **lenient legacy decoder**. Frontend's stance on
  Open Q3 (migration appetite): *no migration pass* — new writes use the new
  format, old files decode leniently. Real libraries are small enough.
- **B2 (backend)** — Reconciler state 7 (audit 1.3): both sides exist, no
  ledger → currently **zero actions emitted** (a second device's first sync
  silently never syncs overlapping files). Equal checksums → adopt-ledger
  action; differing → conflict action. Note the audit's gotcha: verify
  `GoogleDriveRemoteFileProvider.listManifest` populates remote `md5Checksum`,
  and route new conflict downloads through `previewRemoteOverwrites` so the
  existing frontend warning dialog covers them.
- **B3 (backend, contract change — frontend pairs)** — Sync error handling
  (audit 1.4): wrap `_syncNowLocked`'s plan build + action loop, emit a
  terminal **`SyncPhase.error`** status (today a thrown action leaves the
  stream stuck on `syncing` forever), and write the ledger for
  already-completed actions. Please post the final `SyncStatus`/`SyncPhase`
  shape in `back_to_frontend.md`; frontend item FE1 below consumes it.
- **B4 (backend)** — Directory move in the web JS bridge (audit 1.5):
  `organoteFs.move` only handles files, so category move/delete should throw
  `TypeMismatchError` on web and is non-atomic on partial failure. Recursive
  copy+delete or `handle.move()` where available. Frontend will run the manual
  Chrome verification pass (FE4) once it lands.
- **B5 (backend + user)** — Rotate the committed OAuth Web client ID and
  replace `web/index.html` with a placeholder + build-time injection; scrub
  the real domains from README (audit 1.6 / MEDIUM-3). Needs the user in
  Google Cloud Console for the rotation itself.

### Phase C — High-leverage (backend)

- **C1** — Conflict-loser preservation (audit 2.1): write
  `<name>.conflict-<timestamp>.md` before any last-write-wins overwrite.
  Frontend's stance on Open Q4: LWW + conflict copies is acceptable; no
  interactive resolution UI planned, so don't over-invest in warning flows.
  Frontend item FE2 will make conflict copies presentable in the library.
- **C2** — FileStore contract-test suite run against `MemoryFileStore` and
  `NativeFileStore` including directory-move (audit 2.2) — this is what lets
  HIGH-2-class parity gaps surface in tests instead of in Chrome.
- **C3** — Decouple build from the `.env` asset (audit 2.3) so a fresh clone
  builds with zero manual steps; update the CI step from A1 accordingly.
- **C4** — Parse the trash index as JSON, not regex (audit 2.4).

### Frontend-owned items (tracked here; no backend action needed)

- **FE1** — Render the new terminal error state from B3 in Settings → Sync
  (status pill + message, recover to idle on next action) and anywhere the
  sync badge appears in `WebShell`. Widget coverage in
  `test/ui/settings_screen_test.dart`. *Depends on B3.*
- **FE2** — Conflict-copy UX: `*.conflict-<ts>.md` files will appear as
  library notes after C1. Frontend will make sure NoteCard/viewer render them
  sanely (compact "Conflict copy" pill, easy delete), no new screen.
  *Depends on C1.*
- **FE3** — Confirm the existing `SyncOverwriteWarning` dialog presents B2's
  new conflict-download entries correctly (wording: "Conflict" pill where the
  newer side is ambiguous). *Depends on B2.*
- **FE4** — Manual web verification pass for category move/delete/trash-restore
  on Chrome after B4.
- **FE5 (polish, unsequenced)** — Split `settings_screen.dart` and
  `web_shell.dart` into per-pane files (audit 3.4 partial); repo hygiene
  (audit 3.3): remove tmux logs/screenshot, gitignore `*.iml`, parameterize
  the flutter path in README, add LICENSE.

### Phase D — Polish (deferred; pick up after zero Critical/High)

- 3.1 incremental snapshot updates instead of full `reload()` — defer until a
  real library size hurts.
- 3.2 `scheduleFocusedSync` is dead code — frontend recommendation (Open Q2):
  **delete it**; background focus-sync isn't planned, and if it ever is it
  must come after B3's error handling anyway.
- 3.5 trash retention — frontend recommendation (Open Q1): keep syncing
  `trash/` (cross-device trash is good UX), add a count-capped purge later as
  a product decision.

### Open-question defaults (user can override any of these)

| Audit Q | Default adopted in this plan |
|---|---|
| Q1 trash sync | Keep syncing; retention later (D/3.5) |
| Q2 `scheduleFocusedSync` | Delete (D/3.2) |
| Q3 format migration | Lenient decode, no migration pass (B1) |
| Q4 conflict policy | LWW + conflict copies, no interactive UI (C1/FE2) |
| Q5 web status | First-class — user actively deploys web, so B4/C2 are release-blocking |
| Q6 uncommitted diff | Finished work → milestone commit now (A0) |

### Phase A status (2026-06-10)

- **A0 done** — the Drive overwrite-preview milestone is committed
  (`a5210e4`), the audit + this plan are committed separately (`c346e08`),
  the stray screenshot is gitignored, and analyze + all 141 tests passed
  immediately before the commit.
- **A1 done** — `.github/workflows/ci.yml` runs checkout →
  `cp .env.example .env` → `flutter pub get` → `flutter analyze
  --fatal-infos` → `flutter test` on pushes to `main` and on PRs, pinned to
  Flutter 3.41.0 stable (the local toolchain; satisfies SDK ^3.11) with pub
  caching. Note for C3: the `.env` materialization step carries an inline
  comment so it's easy to find and remove when the build is decoupled from
  the asset. If CI ever flakes on font fetching, the audit's suggested fix is
  `GoogleFonts.config.allowRuntimeFetching = false` in a test bootstrap —
  not applied since the suite doesn't fetch today.
- **A2/A3 are now unblocked** — backend can start the codec round-trip and
  reconciler state-matrix characterization tests; Phase B should not start
  before those land.

### Phase B frontend status (2026-06-10)

- **FE3 done** (depended on B2, which backend reports done). Verified that
  `previewRemoteOverwrites()` already includes B2's no-ledger conflict
  downloads: `_remoteOverwriteWarnings` filters on
  `_downloadsRemoteToExistingLocal`, which matches
  `downloadRemoteConflictWinner`, so the existing warning dialog covers them
  with no contract change. One wording fix landed in
  `lib/ui/screens/settings/settings_screen.dart`: an equal-timestamp row with
  a planned download means the copies diverged and neither side is provably
  newer, so its pill now reads **`Conflict`** (warning hue) instead of the
  misleading `Same time`. `Local newer` keeps the danger styling and top sort
  rank. Widget coverage extended in `test/ui/settings_screen_test.dart` with a
  state-7-style equal-timestamp entry. `flutter analyze` clean, all 157 tests
  pass.
- Remaining frontend items stay blocked on backend: **FE1** needs B3's final
  `SyncStatus`/`SyncPhase.error` shape (please post it here when ready),
  **FE2** needs C1's conflict-copy files, **FE4** needs B4's web directory
  move. Frontend will pick up FE5 polish while waiting.
