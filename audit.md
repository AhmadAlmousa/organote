# Organote — Technical Audit & Improvement Plan

> Audit date: 2026-06-10. Analysis only — no code was modified.
> Findings labeled **(fact)** were verified by reading code at the cited
> location; three were additionally **confirmed by executing probes** against
> the repo's actual code (`dart run` with the repo package config, scripts kept
> outside the repo). Findings labeled **(judgment)** are assessments.

## Executive Summary

**Overall health: B−.** Organote is a well-architected, genuinely test-covered
Flutter app (~30.6k lines of Dart, 141 passing tests, zero analyzer issues
under strict mode) with clean layering between domain, data, services, and UI.
However, the codebase has **three confirmed data-corruption bugs in the
markdown round-trip and sync core** — the exact code paths a local-first notes
app must never get wrong — and the entire safety story relies on developers
remembering to run tests locally, since there is no CI.

**Top 3 risks:**

1. Multiline field values and markdown bodies with `##` headings are silently
   destroyed on autosave round-trip.
2. The sync reconciler silently skips files that exist on both sides with no
   ledger entry — the exact state of a second device's first sync.
3. Category move/delete is broken on web because the web bridge can only move
   files, not directories.

**Top 3 opportunities:**

1. A property-based round-trip test for the codec would have caught two of the
   three bugs and will guard all future format changes.
2. A 10-line GitHub Actions workflow converts the existing strong test suite
   into an enforced gate.
3. Splitting `reload()`-per-mutation into incremental updates removes the main
   scalability ceiling.

The project is a maturing personal/portfolio app heading toward real use;
recommendations are calibrated to that, not enterprise scale.

---

## Phase 1 — Repo Map

**Purpose:** Local-first structured notes app. The filesystem is the database:
notes and templates are human-readable Markdown files in a user-chosen folder,
with templates defining typed, validated fields. Optional Google Drive sync via
a custom 3-way (local/remote/ledger) reconciliation engine. Targets Android and
desktop web (File System Access API). Per `plan.md`, built deliberately by two
coordinated agents ("frontend"/"backend") communicating through
`front_to_backend.md` / `back_to_frontend.md`.

**Stack:** Flutter (SDK ^3.11), Dart. State: Riverpod (bridging to get_it
singletons). Key packages: `googleapis`/`google_sign_in` (Drive), `archive`
(backup zips), `file_picker`, `gpt_markdown`, `flutter_dotenv`. No codegen, no
backend server.

**Architecture sketch (data flow):**

```text
UI (Riverpod providers) ──▶ Repository interfaces (domain/repositories)
                                  │
                  LocalOrganoteRepository (data/repositories)
                  — one class implements all 7 contracts
                  │           │              │
            MarkdownCodec  ComplianceService  BackupService
                  │
              FileStore (abstract)
                  ├─ NativeFileStore (dart:io)
                  └─ WebFileSystemAccessStore (JS interop → web/organote_file_system.js)

GoogleDriveSyncRepository ──▶ SyncReconciler (pure) + SyncLedgerStore
                              + GoogleDriveRemoteFileProvider
```

**Key directories:**

| Path | What it is |
|---|---|
| `lib/domain/` | Pure models + repository contracts (immutable, copyWith style) |
| `lib/data/` | Markdown codec, field validator, the all-in-one local repository |
| `lib/services/` | storage (per-platform FileStore), sync engine, compliance scans, backup, error log |
| `lib/ui/` | screens, ~30 widgets, theme tokens, Riverpod state; `app/web_shell.dart` is the 3-pane desktop-web shell |
| `web/organote_file_system.js` | Hand-written File System Access API bridge with IndexedDB handle persistence |
| `test/` | 141 tests: thorough service/data coverage plus behavioral widget tests |
| `plan.md`, `*_to_*.md` | Design spec and inter-agent coordination logs |

**Surprises:** (a) the dual-agent workflow docs are unusually disciplined and
accurate; (b) a real OAuth client ID is committed in `web/index.html` despite
the README's own redaction policy; (c) ~836 lines of uncommitted work sit in
the working tree (Drive-mirror feature, per `git status`); (d) `.env` is
declared as a bundled Flutter asset.

**Conventions to preserve:** strict analyzer flags
(`analysis_options.yaml:12-16`), constructor injection with interface
contracts, pure/testable services (`SyncReconciler`, `ComplianceService`,
`MarkdownCodec` are all stateless and const-constructible), behavioral widget
tests with `MemoryFileStore`.

---

## Phase 2 — Audit Report

### Correctness / Architecture

**🔴 CRITICAL-1 — Multiline record values are silently truncated on
round-trip.** *(fact, empirically confirmed)*
`MarkdownCodec.encodeNote` writes record values raw on a single bullet line
(`lib/data/markdown/markdown_codec.dart:98`), but `_MarkdownRow.tryParse`
(`lib/data/markdown/markdown_codec.dart:364-372`) only matches one line. Probe
result: value `'line one\nline two\nline three'` round-trips to `'line one'`.
The template builder explicitly supports multiline text fields and the editor
renders them (`lib/ui/screens/note_editor/note_editor_screen.dart:1932-1934`),
and the 2-second autosave (`note_editor_screen.dart:43,441`) immediately
rewrites the file — so typing a second line into a multiline field
**permanently destroys** it on the next load+save cycle. No test covers this
(`test/data/markdown/markdown_codec_test.dart` has multiline *body* coverage
only, line 253).

**🔴 CRITICAL-2 — Note bodies containing `## ` headings are dismembered on
round-trip.** *(fact, empirically confirmed)*
`decodeNote` splits content on every line starting `## `
(`markdown_codec.dart:247`), so a body of `Intro.\n\n## Section A\n…` decodes
as `body: 'Intro.'` plus phantom records `[Section A, Section B]`. The next
autosave re-encodes those phantom records with `- **record id**:` lines —
progressive corruption of ordinary Markdown notes, in direct conflict with
`plan.md`'s "conventional markdown formatting" requirement.

**🔴 HIGH-1 — Sync reconciler silently ignores the "exists on both sides, no
ledger" state.** *(fact, empirically confirmed)*
`SyncReconciler.reconcile` (`lib/services/sync/sync_reconciler.dart:17-139`)
handles six enumerated states, but `local≠null ∧ remote≠null ∧ ledger=null`
falls through every branch — probe confirmed **zero actions emitted** for
divergent copies. This is precisely the state of a fresh install / second
device syncing against a Drive folder that already holds the library: every
overlapping file is silently never synced, with no conflict, no error, no log.
The test suite's state enumeration
(`test/services/sync/sync_reconciler_test.dart:44-296`) has the same blind
spot.

**🟠 HIGH-2 — Category move/delete is broken on web: the JS bridge can only
move files.** *(fact, code-derived — not executed in a browser)*
`organoteFs.move` does read-bytes→write→delete via `fileHandle()`
(`web/organote_file_system.js:255-259`), which throws for directories. But
`LocalOrganoteRepository.moveCategory`/`deleteCategory` move whole directories
(`lib/data/repositories/local_organote_repository.dart:322,343`). On web these
operations should fail with an unhandled `TypeMismatchError`; on partial
failure `move` is also non-atomic (copy committed, delete failed → duplicate
data). Tests mask this because `MemoryFileStore` handles directory moves.

**🟠 HIGH-3 — `_syncNowLocked` has no error handling; a single failed action
aborts sync and leaves status stuck at "syncing".** *(fact)*
`lib/services/sync/google_drive_sync_repository.dart:240-295`: no try/catch
around plan building or the action loop; an exception mid-loop skips the
ledger write and never emits an error `SyncStatus`. The Settings caller catches
and logs (`lib/ui/screens/settings/settings_screen.dart:135-146`), but the
status stream — which drives the UI badge — stays in `SyncPhase.syncing`
forever. Also, because actions execute sequentially with the ledger written
only at the end (`:285`), one Drive 5xx abandons progress tracking for the
already-executed uploads (they will re-reconcile correctly, but
conflict-winner decisions get re-made against new clocks).

**🟡 MEDIUM-1 — Conflict resolution is last-write-wins by wall clock, with no
conflict copy.** *(fact + judgment)*
`sync_reconciler.dart:70-79` picks a winner by comparing `modifiedAt` across
two machines' clocks; the loser's content is overwritten with no
`*.conflict.md` preserved. For a notes app this converts clock skew directly
into silent data loss. The `previewRemoteOverwrites` warning flow mitigates
this only for the manual connect path.

**🟡 MEDIUM-2 — `reload()` re-reads and re-parses the entire library on every
mutation.** *(fact)*
Every save, pin, favorite, ignore-toggle calls `reload()`
(`local_organote_repository.dart:170,184,221,…`), which lists and reads
**every** note and template file (`:434-477`) and re-runs the full compliance
scan. With autosave every 2 seconds, editing in a 1,000-note library means
continuous full-library rescans — on web, through the JS-interop byte-array
bridge (`lib/services/storage/file_store_web.dart:183-189` marshals files as
individual JS numbers). Fine today; the first scalability wall.

**🟢 LOW-1 — One class implements seven repository interfaces.** *(judgment)*
`LocalOrganoteRepository` (`local_organote_repository.dart:14-22`) is the
god-object risk in an otherwise clean design. At 686 lines it is still
manageable; worth watching, not worth refactoring yet.

**🟢 LOW-2 — Fragile internal parsing.** *(facts)*
Trash index parsed with regex instead of JSON
(`google_drive_sync_repository.dart:451-461`); asset references harvested by
regex over note text (`:436-449`); `_newId()` is a microsecond timestamp
(`local_organote_repository.dart:674`) — collision-able under rapid creation.

### Security

**🟡 MEDIUM-3 — Real OAuth Web client ID committed in `web/index.html:26`**,
contradicting the README's own policy ("do not commit real project-specific
IDs", `README.md:239-241`). OAuth web client IDs are not secrets in the
credential sense, but this one is now in history along with the personal
domains in `README.md:206,221`. Consequence: quota abuse /
phishing-impersonation surface, and policy drift. *(fact)*

**🟢 LOW-3 — `.env` is bundled into release APKs** (`pubspec.yaml:84`) —
acknowledged in README and only holds client IDs today, but it's a standing
trap for the day someone adds a real secret to `.env`. *(fact)*

**Healthy:** path traversal is properly guarded at all three layers
(`lib/services/storage/file_store.dart:103-112`,
`lib/services/storage/file_store_io.dart:197-205`,
`web/organote_file_system.js:16-19`); backup restore normalizes zip entry
paths (`lib/services/backup/backup_service.dart:37`); Drive scope is correctly
minimal (`drive.file`); asset reads are confined to `assets/`
(`local_organote_repository.dart:390-397`).

### Testing

**🟠 HIGH-4 — No CI whatsoever.** No `.github/`, no workflow files. *(fact)*
The suite is genuinely good — 141 tests, services covered end-to-end, widget
tests assert behavior (e.g., `test/ui/settings_screen_test.dart` exercises
trash restore and compliance flows) — but nothing enforces it. Combined with
~836 uncommitted lines in the working tree, regressions ride on discipline
alone.

**🟡 MEDIUM-4 — The core invariant of the whole product — markdown round-trip
fidelity — has no property/fuzz test.** *(fact)* All three confirmed
Critical/High bugs live in exactly the gaps the example-based tests don't
reach (multiline values, `##` in bodies, reconciler state 7).

### Performance

Covered by MEDIUM-2; additionally `_buildLocalManifest` MD5-hashes every file
including all image assets on every sync
(`google_drive_sync_repository.dart:421-434`), and `ErrorLogService._append`
rewrites the whole log per entry (capped at 256 KB,
`lib/services/logging/error_log_service.dart:81-99` — acceptable). Trash grows
unboundedly and is itself synced to Drive (`_isSyncableFile` includes
`trash/`, `google_drive_sync_repository.dart:528`) — deliberate, but worth a
retention policy eventually. *(facts)*

### Dependencies

Healthy. Essentially current (`flutter pub outdated`: only patch-level lag
plus `share_plus` one major behind), lockfile committed, no unmaintained
packages spotted. One judgment: both `get_it` and `flutter_riverpod` serve as
DI (`lib/ui/state/app_providers.dart:15-54` wraps getIt in providers) —
redundant but harmless as a bridging pattern; the project convention is
Riverpod.

### DevEx / Docs

**🟡 MEDIUM-5 — Fresh clone cannot build: `.env` is a declared asset
(`pubspec.yaml:84`) but gitignored.** Without `cp .env.example .env`,
`flutter build` fails on the missing asset. The README does mention the copy
step (`README.md:81-88`), but the failure mode is a confusing asset error, and
CI (once added) will hit it immediately. *(fact; failure mode inferred from
standard Flutter behavior, not executed)*

**🟢 LOW-4 —** Dead code: `scheduleFocusedSync` is never called
(`google_drive_sync_repository.dart:235`, grep-verified). Repo clutter:
`tmux-*.log`, `organote.iml`, root-level screenshot, `.idea/` present in the
worktree (mostly gitignored). README hardcodes
`/home/ahmad/flutter/bin/flutter` throughout. No LICENSE file. *(facts)*

### Strengths (preserve these)

- **Clean layering with real contracts** — UI consumes only repository
  interfaces; the frontend/backend boundary documented in
  `back_to_frontend.md` is actually honored in code.
- **Pure, deterministic core services** — `SyncReconciler`,
  `ComplianceService`, `MarkdownCodec` are stateless and trivially testable;
  reconciler actions are sorted for determinism (`sync_reconciler.dart:141`).
- **Strict static analysis passes clean** (strict-casts/inference/raw-types),
  a high bar few Flutter projects meet.
- **Serious test culture for a solo project** — 141 behavioral tests
  including web-shell keyboard shortcuts and sync end-to-end.
- **Security fundamentals done right** — path confinement at every layer,
  minimal OAuth scope, storage-gate UX.
- **Error logging design** — opt-in, capped, never throws
  (`error_log_service.dart:89-91`), zone + platform hooks wired in
  `lib/main.dart:51-62`.

---

## Phase 3 — Improvement Strategy

**Theme 1: The file format is the product, but round-trip fidelity is
unguaranteed.**
Both Critical bugs are the same root cause: an informal encode/decode pair
with no escaping rules and no round-trip invariant test. *Target state:* a
documented escaping scheme (e.g., indent continuation lines under their
bullet, or fence multiline values) plus a property-style test asserting
`decode(encode(note)) == note` for generated notes covering newlines, `##`,
`---`, unicode, and empty values. *Principle:* in a local-first app, the codec
is the database engine — it gets database-engine-grade testing.

**Theme 2: Sync is one missing state away from silently losing the user's
library.**
The reconciler is well-built but its state machine is incomplete (HIGH-1), its
failure path is unhandled (HIGH-3), and its conflict policy destroys data
(MEDIUM-1). *Target state:* exhaustive state-matrix coverage (8 combinations
of local/remote/ledger presence × changed flags), an error-terminal
`SyncStatus`, and conflict-loser preservation as
`<name>.conflict-<timestamp>.md`. *Principle:* sync must be safe-by-default —
when uncertain, keep both copies.

**Theme 3: Quality is real but unenforced.**
Excellent tests, strict lints, zero CI, large uncommitted diffs. *Target
state:* CI running `flutter analyze` + `flutter test` on every push (with
`.env` materialized from `.env.example` in the workflow), and the working tree
kept near-clean per the existing commit-per-milestone practice. *Principle:*
make the safety net automatic, not behavioral.

**Theme 4: Platform parity gaps hide behind the in-memory test store.**
Web directory-move breakage (HIGH-2) survives because `MemoryFileStore` is
more capable than the real web store. *Target state:* a shared FileStore
contract-test suite run against `MemoryFileStore` and `NativeFileStore` (and
manually validated on web), plus directory-move support in the JS bridge.

**Explicitly NOT recommending:** splitting `LocalOrganoteRepository` (cohesive
enough; splitting now is churn), replacing the get_it/Riverpod duality
(working bridge, low payoff), incremental reload / sync performance work
beyond Milestone 3 (no evidence of real libraries at the scale where it
hurts), localization/Arabic (deferred in plan.md), enterprise observability
(it's a local-first personal app), and rewriting regex-based trash parsing as
standalone work (fold it into sync hardening only).

**"Done" signals:** CI green-gate on main; round-trip property test in suite;
reconciler test matrix covers all 8 presence states; zero Critical and zero
High findings open; fresh
`git clone && cp .env.example .env && flutter test` succeeds on a clean
machine — and in CI.

---

## Phase 4 — Task Plan

### Milestone 0 — Safety net (before touching the codec or sync)

| # | Task | Files | Acceptance | Effort | Risk | Deps |
|---|---|---|---|---|---|---|
| 0.1 | **Add CI workflow** (analyze + test, materialize `.env` from example) | `.github/workflows/ci.yml` | PR/push runs analyze+test; failure blocks | **S** | None | — |
| 0.2 | **Commit or shelve the 836-line working-tree diff** (Drive mirror work) | 11 modified files | `git status` clean; milestone commit per existing convention | **S** | Low | — |
| 0.3 | **Codec round-trip characterization tests** — encode/decode property test over generated notes (multiline values, `##`/`---` in bodies, unicode, empties); mark currently-failing cases as `skip: true` with bug refs | `test/data/markdown/` | Failing invariants documented in-suite | **M** | None | — |
| 0.4 | **Reconciler full state-matrix test** — all 8 local/remote/ledger presence combos; the both-new-no-ledger case initially skipped+referenced | `test/services/sync/sync_reconciler_test.dart` | Matrix exhaustive | **S** | None | — |

### Milestone 1 — Critical correctness

| # | Task | Files | Acceptance | Effort | Risk | Deps |
|---|---|---|---|---|---|---|
| 1.1 | **Fix multiline value round-trip** (CRITICAL-1) | `markdown_codec.dart` | 0.3 tests pass unskipped; legacy files still decode | **M** | Medium — format change; needs backward-compat decode | 0.3 |
| 1.2 | **Fix body `##` dismemberment** (CRITICAL-2) | `markdown_codec.dart` | Body with H2s round-trips intact | **M** | Medium — same | 0.3, ideally with 1.1 |
| 1.3 | **Handle reconciler state 7 (both exist, no ledger)** (HIGH-1) | `sync_reconciler.dart` | Equal checksums → adopt into ledger; differing → conflict action; 0.4 test unskipped | **M** | Medium | 0.4 |
| 1.4 | **Sync error handling + terminal status** (HIGH-3) | `google_drive_sync_repository.dart:240-295` | Thrown action error → `SyncPhase.error` emitted, ledger written for completed actions; test added | **S** | Low | — |
| 1.5 | **Directory move in web bridge** (HIGH-2): recursive copy+delete (or `handle.move()` where available) in `organoteFs.move` | `web/organote_file_system.js` | Category move/delete/trash-restore work on Chrome web (manual verify) | **M** | Medium — only manually verifiable | — |
| 1.6 | **Rotate the committed OAuth client ID** and replace `web/index.html:26` with placeholder + build-time injection; scrub real domains from README examples (MEDIUM-3) | `web/index.html`, `README.md`, Google Cloud Console | No real IDs/domains in repo; sign-in still works with injected ID | **S** | Low | — |

### Milestone 2 — High-leverage

| # | Task | Files | Acceptance | Effort | Risk | Deps |
|---|---|---|---|---|---|---|
| 2.1 | **Conflict-loser preservation** — write `*.conflict-<ts>.md` before LWW overwrite (MEDIUM-1) | sync repo + reconciler | Conflict download/upload never discards bytes; test proves it | **M** | Low | 1.3, 1.4 |
| 2.2 | **FileStore contract-test suite** run against Memory + Native stores (catches parity gaps like HIGH-2 class) | `test/services/storage/` | Same suite passes for both stores; directory-move case included | **M** | None | — |
| 2.3 | **Decouple build from `.env` asset** — drop from `pubspec.yaml` assets, rely on `--dart-define` / generated config, or generate a stub in CI (MEDIUM-5, LOW-3) | `pubspec.yaml`, `main.dart`, README, CI | Fresh clone builds with zero manual steps | **M** | Medium — touches the fiddly OAuth config matrix | 0.1 |
| 2.4 | **Parse trash index as JSON, not regex** (LOW-2 partial) | `google_drive_sync_repository.dart:451-461` | Reuses repository's JSON reader; regex gone | **S** | Low | — |

### Milestone 3 — Quality & polish

| # | Task | Effort | Notes |
|---|---|---|---|
| 3.1 | Incremental snapshot updates: mutate `_snapshot` for single-note saves instead of full `reload()` (MEDIUM-2) | **L** | Only when library sizes warrant; keep `reload()` as the fallback path |
| 3.2 | Remove dead `scheduleFocusedSync` or wire it to lifecycle focus events | **S** | Decide intent first (see Open Questions) |
| 3.3 | Repo hygiene: delete tmux logs/screenshot, gitignore `*.iml`, parameterize flutter path in README, add LICENSE | **S** | |
| 3.4 | UUID-ish `_newId()` instead of microsecond timestamp; split `web_shell.dart`/`settings_screen.dart` into per-pane files | **S–M** | Cosmetic-to-structural; low urgency |
| 3.5 | Trash retention policy (age- or count-based purge) and exclude `trash/` from sync, or document why it syncs | **M** | Product decision required |

### Quick wins (high impact, S effort — do immediately)

- 0.1 CI workflow
- 0.2 Commit the in-flight Drive-mirror work
- 1.4 Sync error status
- 1.6 Rotate/remove the committed OAuth client ID
- 2.4 JSON trash parsing

### Implementation sketches — top 3 tasks

**1.1 / 1.2 — Codec round-trip fixes (do together; one format revision).**
Approach: keep the bullet format but define escaping: multiline values
serialize as the bullet line followed by continuation lines indented two
spaces (`- **notes**: line one\n  line two`); the decoder accumulates indented
lines following a row into its value. For bodies, fence the body section: emit
`## Body` followed by content with any line starting `#` escaped, or simpler —
delimit body with an HTML comment sentinel (`<!-- organote:body -->`) the
section splitter respects. Gotchas: (a) backward compatibility — old files
have no markers; decode must accept both shapes; (b) `_headingForRecord`'s
first-value-as-heading optimization (`markdown_codec.dart:190-203`) already
skips multiline values — keep that; (c) the raw source editor lets users write
arbitrary text, so the decoder must stay lenient while the encoder becomes
strict. Key steps: write the escaping spec in a doc comment → unskip 0.3 tests
→ fix encoder → fix decoder with legacy fallback → run full suite.

**1.3 — Reconciler state 7.**
Approach: in the branch chain, add `local≠null ∧ remote≠null ∧ ledger=null`
*before* the three-non-null case: if
`localEntry.checksum == remoteEntry.checksum` (note: requires remote checksums
— Drive provides `md5Checksum` for binary uploads; verify
`GoogleDriveRemoteFileProvider.listManifest` populates it, else fall back to
size+download-compare or treat as conflict), emit a new `adoptLedger` action
that seeds the ledger without transfer; otherwise emit a conflict action that
flows through 2.1's conflict-copy path. Gotchas: `SyncPlanActionType` is
exhaustive-switched in `_executeAction`
(`google_drive_sync_repository.dart:473`) — adding a variant forces handling
everywhere (good); preview warnings (`previewRemoteOverwrites`) must include
the new conflict downloads.

**0.1 — CI workflow.**
`flutter-version` pinned (3.x matching SDK ^3.11), steps: checkout →
`cp .env.example .env` (until 2.3 lands) → `flutter pub get` →
`flutter analyze --fatal-infos` → `flutter test`. Gotchas: `google_fonts` may
fetch at test time — it doesn't in this suite (no font loading in tests
observed), but if CI flakes, set
`GoogleFonts.config.allowRuntimeFetching = false` in a test bootstrap. Runtime
~5 min; cache `~/.pub-cache`.

---

## Open Questions

1. **Sync of `trash/`:** trash is currently synced to Drive and never purged —
   intentional (cross-device trash) or accidental? Determines task 3.5's
   direction.
2. **`scheduleFocusedSync`** (`google_drive_sync_repository.dart:235`) is dead
   — was automatic background sync planned? If yes, it needs the 1.4 error
   handling first; if no, delete it.
3. **Format migration appetite:** fixing CRITICAL-1/2 changes the on-disk
   format. Are there existing real libraries that need a migration pass, or is
   the data small enough to accept "new writes use new format, old files
   decode leniently"?
4. **Conflict policy:** is last-write-wins + conflict copies (2.1) acceptable,
   or is interactive conflict-resolution UI wanted eventually? Affects how
   much to invest in `SyncOverwriteWarning` flows.
5. **Web as a first-class target:** HIGH-2 suggests web gets less manual
   testing than Android. Should web category management be release-blocking,
   or is web a secondary preview platform for now?
6. **The uncommitted Drive-mirror work** (~836 lines): finished and awaiting a
   milestone commit, or mid-flight? It touches the same sync files Milestone 1
   will modify, so its fate sequences the whole plan.
