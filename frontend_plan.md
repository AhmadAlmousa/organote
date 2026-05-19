# Organote — Frontend Implementation Plan

> Owner: frontend AI agent. Backend agent owns `lib/domain/**`, `lib/data/**`,
> `lib/services/**`, `lib/di/**`, `pubspec.yaml`, and `web/index.html`. Coordination
> happens in `front_to_backend.md` (frontend → backend) and `back_to_frontend.md`
> (backend → frontend).

## Context

Build a highly polished, animated Flutter UI for **Organote** — a local-first
structured-markdown notes app for Android and Web. The backend agent has shipped
domain models, repositories, file storage (Android native + Web File System Access),
markdown codec, Google Drive sync, compliance and backup behind clean interfaces
exposed via `lib/di/service_locator.dart` and `lib/domain/repositories/repositories.dart`.
The existing `lib/ui/app_shell.dart` is a placeholder approved for replacement.

The product spec lives in `plan.md`. The visual language is captured by the hi-fi
mobile mockup in `mockup/project/` and the design intent in `mockup/chats/chat1.md`:
playful & bright, saturated mint accent, big rounded cards, springy motion,
dark-OLED-first.

## Design language (locked from mockup + chat)

| Token | Value |
| --- | --- |
| Type — UI | Plus Jakarta Sans (400/500/600/700/800) |
| Type — code/IPs/passwords | JetBrains Mono (400/500/600) |
| Accent presets | Mint(175°), Violet(295°), Coral(25°), Lemon(95°), Azure(240°) |
| Category colors | Per-category hue stored as `colorHex` on the `Category` model |
| Surfaces | OkLCH(0.23 0.014 hue) dark · OkLCH(1 0 0) light · pure `#000` OLED |
| Motion curve | `Cubic(0.34, 1.56, 0.64, 1.0)` — springy overshoot |
| Tap feedback | scale 0.96–0.98 · 150–180 ms |
| Hover lift | -2 px translateY · 180 ms |
| Sheet slide-up | 320 ms `cubic(.34,1.16,.64,1)` |
| Copy ripple | radial expand to 40× in 650 ms |
| Radii | 10 / 14 / 16 / 20 / 22 (rows · pills · fields · cards · app-bar) |

OkLCH → sRGB via a small utility (`lib/ui/util/oklch.dart`) so any hue rotates smoothly.

## Architecture & file layout

```
lib/ui/
├── organote_app.dart                 # MaterialApp, theme wire-up, root provider
├── app/
│   ├── adaptive_shell.dart           # breakpoint switch (≤900 mobile · >900 web)
│   ├── mobile_shell.dart             # glass tab bar + overlay stack
│   ├── web_shell.dart                # 3-pane (slim nav · list · content)
│   ├── overlay_route.dart            # springy slide-up route
│   └── splash_screen.dart            # init / storage gate
├── theme/
│   ├── theme_controller.dart         # ChangeNotifier; persists via SharedPreferences
│   ├── app_theme.dart                # ThemeData (light/dark/oled)
│   ├── color_tokens.dart             # OrgColors, hue table, OkLCH→Color
│   ├── motion.dart                   # OrgCurves, OrgDurations
│   ├── density.dart                  # OrgDensity InheritedWidget (compact/comfortable)
│   └── typography.dart               # google_fonts wiring + text styles
├── widgets/
│   ├── wordmark.dart
│   ├── glass_panel.dart              # BackdropFilter surface
│   ├── org_icon_button.dart
│   ├── org_chip.dart                 # category chip + count
│   ├── org_segmented.dart            # animated 3-way toggle
│   ├── org_toggle.dart               # spring switch
│   ├── org_fab.dart                  # FAB with glow + spring + rotate
│   ├── org_search_bar.dart
│   ├── org_empty_state.dart
│   ├── org_toast.dart                # springy bottom toast
│   ├── org_tab_bar.dart              # glass bottom nav with active pill
│   ├── side_nav_rail.dart            # slim icon rail for web
│   ├── copy_ripple.dart              # tap-to-copy ripple painter
│   ├── copy_field.dart               # bordered standalone
│   ├── copy_row.dart                 # borderless row inside record card
│   ├── note_card.dart                # compact list card
│   ├── template_card.dart            # used/unused row
│   ├── record_card.dart              # viewer record group
│   ├── form_field/                   # one component per field type
│   │   ├── form_field_host.dart
│   │   ├── text_field_impl.dart
│   │   ├── number_field_impl.dart
│   │   ├── boolean_field_impl.dart
│   │   ├── dropdown_field_impl.dart
│   │   ├── password_field_impl.dart
│   │   ├── url_field_impl.dart
│   │   ├── ip_field_impl.dart
│   │   ├── regex_field_impl.dart
│   │   ├── date_field_impl.dart      # dual Gregorian + Hijri (`hijri` pkg)
│   │   ├── image_field_impl.dart
│   │   └── custom_label_impl.dart
│   ├── emoji_picker_button.dart      # uses emoji_picker_flutter
│   ├── tag_input.dart                # autocomplete from LibrarySnapshot.tags
│   ├── category_selector.dart        # chip row + add-new dialog
│   ├── field_type_picker_sheet.dart  # 11-cell bottom sheet
│   ├── reorderable_field_list.dart   # custom spring reorder
│   └── compliance_pill.dart          # AppBar badge
├── screens/
│   ├── home/home_screen.dart
│   ├── templates/templates_screen.dart
│   ├── settings/
│   │   ├── settings_screen.dart
│   │   ├── customization_panel.dart  # accent picker, OLED, advanced
│   │   ├── compliance_screen.dart
│   │   ├── trash_screen.dart
│   │   ├── data_management.dart
│   │   └── sync_section.dart
│   ├── note_viewer/note_viewer_screen.dart
│   ├── note_editor/
│   │   ├── note_editor_screen.dart   # structured GUI editor
│   │   └── raw_source_editor.dart    # split-pane markdown w/ gpt_markdown
│   └── template_builder/template_builder_screen.dart
├── state/
│   ├── library_provider.dart
│   ├── note_compose_controller.dart
│   ├── template_compose_controller.dart
│   ├── search_controller.dart
│   ├── compliance_controller.dart
│   └── sync_controller.dart
└── util/
    ├── relative_time.dart
    ├── debouncer.dart
    ├── share_text_builder.dart
    └── oklch.dart
```

State via `provider`. Backend streams; UI subscribes and composes ephemeral edits in
`*_compose_controller`s.

## Adaptive layout

- **Mobile** (`shortestSide < 600`): MobileShell — bottom glass tab bar; full-screen
  springy overlays for viewer/editor/builder. Hardware back auto-saves before pop.
- **Tablet** (`600..900`): MobileShell with widened gutters; overlays still cover.
- **Web/Desktop** (`>= 900`): WebShell — 3-pane split with a **denser desktop variant**:
  - Pane 1 (64 px slim rail): Home / Templates / Settings + profile/theme pinned bottom.
  - Pane 2 (~320 px list pane): Notion/Linear-style dense single-line rows — title,
    inline category dot, micro time, hover row highlight only. Compact 44 px search +
    chip bar pinned at top. Narrows to 280 px when window is tight.
  - Pane 3 (flex): playful card aesthetic for viewer/editor/builder retained — same
    20 px radius, motion, ripples, just framed inside the desktop layout.
  - Selecting a list item slide-fades content in pane 3 (200 ms, no overlay).
- Shared widgets read `OrgDensity.of(context)` → `compact` (web list) or `comfortable`
  (mobile + web content). Density tokens shrink heights/typography one notch in compact.

## Screen-by-screen blueprint

### Home (`home_screen.dart`)
Greeting + Wordmark + search + horizontal chip row + reactive note list + FAB.
ChipRow last item = pen icon → CategoryEditor. NoteCard: category corner dot, template
label, pin/favorite, tags, relative time. Search filters title/tags/record values
in-memory from `LibrarySnapshot.notes`.

### Templates (`templates_screen.dart`)
Stats banner (total / used / unused / total fields) + used/unused sections. Used row
exposes "show associated notes". Unused row has inline "+ create note from this template".

### Settings (`settings_screen.dart`)
Custom grouped rows. Sections: Sync · Compliance · Data (storage path, trash, backup,
restore) · Customization (theme/accent/OLED + Advanced) · Danger Zone.

### Customization Panel
Built into Settings (the "Tweaks" floating panel from the mockup is a design-tool
construct, not a runtime feature). Accent: 5 preset chips + hue slider (advanced).
OLED: enabled only when Dark active. Loading animation picker.

### Note Viewer (`note_viewer_screen.dart`)
Top gradient washed in category hue. Records as borderless cards with header
`#N · record name` + per-field CopyRow. Tap row → ripple + copy + toast (650 ms ripple,
1.2 s state). Password rows have show/hide. Image fields → thumbnails → scrollable
viewer overlay. "Share as plain text" composes via `share_text_builder.dart`. Header
menu: edit · share · delete · edit template · raw source.

### Note Editor (`note_editor_screen.dart`)
Structured GUI form, multi-record ("+ Add record"). Each record renders the template
fields via `FormFieldHost`. Title sanitizes to filename on save (collision suffix
handled by backend). 2 s debounced autosave indicator (typing → autosaving → saved).
Tag autocomplete from `LibrarySnapshot.tags`. Category selector chip row with add-new
+ color picker. Emoji icon picker. Raw source editor opens as overlay (split textarea +
gpt_markdown). Hardware back / route pop auto-flushes.

### Template Builder (`template_builder_screen.dart`)
Top: emoji + name + layout segmented (Cards/Table/Grid). Field list reorderable with
custom springy animation. "+ Add field" → 3-cell bottom-sheet picker of 11 field types.
Each row collapsible to type-specific options (multiline, range, regex pattern + live
tester, dropdown options, dual-calendar mode, etc.). Save → `TemplateRepository.saveTemplate`.

### Compliance Screen *(no mockup — designed in mockup language)*
Header chip = active issue count (animated when > 0). Issues grouped by note in playful
expandable cards; severity dot uses category accent. Actions: Open note · Ignore · Accept
rename (when type is `renameCopySuggestion`). Empty state: big mint check + "All caught up".

### Trash Screen *(no mockup — designed in mockup language)*
Compact card pattern: trashed item icon, original path breadcrumb, "deleted X ago",
trailing Restore / Purge buttons. Top utility row: count + "Empty trash" destructive
with confirm sheet.

### Backup / Restore *(no mockup — designed in mockup language)*
Settings-section + dedicated screen. Export shows progress + saves via FileSaver flow.
Import asks for ZIP via `file_picker`, surfaces a summary (templates/notes/assets counts)
before committing.

### Danger Zone *(no mockup — designed in mockup language)*
Coral-accented card; primary action behind typed-confirmation ("type WIPE"). Calmer
animations here.

### Category Editor *(no mockup — designed in mockup language)*
Bottom-sheet on mobile, side dialog on web. Drag-reorder list, inline rename, hue-wheel
color picker (shares Customization wheel), delete with move-or-purge prompt.

### Splash / Storage gate *(no mockup — designed in mockup language)*
Wordmark center-stage with the springy concentric mint dot bouncing. Native: try
`FileStore.initialize()`; on success animate into shell. Web: "Pick a folder" button
calls `chooseRootDirectory()` directly from gesture. Slim mint indeterminate progress
bar while `LibraryRepository.reload()` runs.

## Theme & motion system

```dart
final scheme = OrgColors.scheme(hue: 175, brightness: Brightness.dark, oled: false);
final theme = OrgTheme.build(scheme); // Plus Jakarta + JetBrains Mono baked in
```

`OrgCurves.spring = Cubic(0.34, 1.56, 0.64, 1.0)` and `OrgDurations` are constants
used everywhere so motion stays consistent.

`ThemeController` (ChangeNotifier) holds: themePreference, accentHue, localeCode,
loadingAnimation. Persists via SharedPreferences under `organote.ui.*` keys.

## Animation polish list

- FAB: scale + 8° rotate on hover, scale 0.94 on press, accent glow shadow.
- Tab bar: active pill spring-slides between tabs; inactive icon greys.
- Note card: hover translateY(-2 px); press scale(0.98).
- Note opening: springy slide-up + cross-fade (320 ms).
- Tap-to-copy: radial CustomPainter ripple + color flash + toast.
- Template field reorder: shift-up/shift-down spring (custom AnimatedPositioned —
  `ReorderableListView` is not springy enough).
- Bottom sheet: 300 ms cubic up-slide + 200 ms backdrop fade.
- Sync state: loading_animation_widget pulse while syncing; green check on done.
- Compliance count badge: subtle pulse if > 0.

## Cross-cutting requirements

- **RTL ready**: `EdgeInsetsDirectional` everywhere; locale switch wired but Arabic
  strings deferred.
- **Cache invalidation**: After save, wait for backend stream tick before popping
  (gotcha §7.4).
- **Sync push lock**: Editor 2 s debounce; queue next save while one in-flight (§7.9).
- **Web focus debounce**: Don't refresh sync on tab focus more than once per 30 s (§7.6).
- **Non-blocking delete UX**: Pop route immediately, soft-delete in background (§7.11).
- **Layout safety**: Never put unbounded flex inside an unbounded parent (§7.1).
- **No comments policy**: Only for non-obvious WHYs.

## Packages we will request via `front_to_backend.md`

| Package | Purpose |
| --- | --- |
| `google_fonts: ^6.2.1` | Plus Jakarta Sans + JetBrains Mono |
| `emoji_picker_flutter: ^4.4.0` | template/note/field icons |
| `gpt_markdown: ^1.1.7` | rich markdown render in raw editor preview |
| `loading_animation_widget: ^1.3.0` | sync-progress animation choices |

## Packages we will skip (with reasoning)

- `syncfusion_flutter_datepicker` — paid commercial license; we build dual picker on
  `hijri` + Flutter's native `showDatePicker`.
- `flutter_form_builder` — backend already validates via `FieldValidator`; mockup field
  UI is custom enough that the package adds weight without payoff.
- `settings_ui`, `google_nav_bar`, `crystal_navigation_bar`, `orient_ui`,
  `sketchy_design_lang`, `moon_design`, `mix`, `fluent_ui`, `yaru`, `blurrycontainer` —
  mockup look is custom; using these dilutes it. Components rolled with primitives +
  `BackdropFilter`.
- `textfield_tags` — small custom widget matches mockup tag UX better.
- `splashscreen` — Flutter's native splash + in-app gate suffices.

## Phased delivery

1. **Foundation** — theme/colors/motion/typography + ThemeController + adaptive_shell
   skeleton + splash + storage gate + replace `app_shell.dart` + wire `main.dart`.
2. **Home** — NoteCard + chip row + search wired to `LibraryRepository.watchLibrary()`.
3. **Note Viewer** — CopyRow ripple + record cards + share builder.
4. **Note Editor** — structured for text/number/dropdown/password/url/ip; debounced save.
5. **Template Builder** — reorder + field-type picker + regex live tester.
6. **Specialized fields** — dual date, image, custom label, multi-line.
7. **Templates screen** — stats + suggested rows.
8. **Settings** — sync section, customization, theme/accent picker, OLED.
9. **Compliance + Trash + Backup/Restore + Danger Zone**.
10. **Raw source editor** — gpt_markdown preview.
11. **Web 3-pane shell** — slim rail + dense list + playful content.
12. **Polish pass** — animations, micro-interactions, empty states, a11y, keyboard
    shortcuts on web, `dart format` + `dart fix` + `flutter analyze` clean.

## Verification

- `mcp__dart__analyze_files` clean.
- `mcp__dart__dart_format` clean.
- `mcp__dart__run_tests` for golden tests (NoteCard, CopyRow ripple, OrgChip active).
- `mcp__dart__launch_app` on Chrome and Android emulator.
- Manual flows via `mcp__dart__flutter_driver` / Chrome DevTools MCP:
  - Pick storage folder on web → empty home → create note → view → tap-to-copy → share
    → edit → save → delete → restore from trash.
  - Build template → add fields → reorder → regex live test → save → create note.
  - Toggle Auto/Light/Dark/OLED → accent change → reload survives via SharedPreferences.
- Visual diff against `mockup/project/index.html` for parity.
