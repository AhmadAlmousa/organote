# Organote App Design

_Started 2026-05-12 00:20 UTC_

---

## User

i'm developing Cross-platform local-first structured note-taking app called Organote using flutter in a modern, responsive, slick, appealing, colorful, animated UI/UX.

Organote bridges the gap between unstructured Markdown and structured database records through a template-driven note system. Each note is a typed, schema-validated markdown file containing metadata frontmatter and a structured data block, allowing for strict data entry alongside freeform text.

The app will have 3 main screens (home, templates, settings)

Home is where notes are listed. Templates is to manage templates in terms of building, editing, and removing. Settings is as the name suggests.

The home screen Presents a list or grid of notes dynamically populated from the local repository. It features horizontal category chips for top-level filtering and a global search bar that queries metadata and titles entirely in-memory.

opening a note switches to Notes Viewer is A read-only presentation rendering structured data sequentially. It includes rapid tap-to-copy functionality. When sharing a note, a parser intercepts the intent, strips schema data, and compiles a clean, human-readable plain-text buffer to push to the OS share sheet.

creating or Editing a note Generates a dynamic visual form bounded by the template schema, handling serialization into frontmatter and data blocks automatically with debounced auto-saving (e.g., a 2-second debounce timer).

Template Builder & Field Schemas

The Template Builder allows users to define strict data entry schemas for their notes. Templates define how their associated notes render in collection views, supporting vertical expandable Cards, data-dense Tables, or adaptive Grids. The system supports a robust catalog of data constraints, including standard inputs (text, digits, boolean, dropdown, password, URL, IP address) and highly specialized elements:
- **Custom Label Field:** A unique field type utilizing a dynamic label-value pair. It acts as a structural element or informational block.
- **Regex Field:** Enforces specific data structures via custom Regular Expression patterns mapped directly to user-facing hint text constraints.
- **Date Field (Dual Calendar):** Uniquely capable of managing a dual calendar mode, simultaneously recording and rendering both standard Gregorian and Hijri calendars. Values are stored with a suffix indicating the active calendar mode.
- **Image Field:** An interactive file-picker field that establishes relative path references to the isolated local assets storage directory.

## Assistant

_[tool: questions_v2]_

## User

Questions answered:
- primary_platform: Mobile (Android frame)
- scope: All 3 screens + note viewer + editor + template builder (full)
- fidelity: Mostly static hi-fi with a few key interactions
- aesthetic: Playful & bright — saturated accents, big rounded cards, springy motion
- color_seed: Teal / mint
- variations: One polished direction
- render_modes_focus: focus on card view for now
- template_examples: server credentials showing server name, ip, url, username, password, os type dropdown
- field_types_showcase: Regex Field with live hint
- category_chips: work, personal, servers
- dark_mode: Dark only
- tweaks: Light/Dark, Color theme / accent
- logo_or_name: No, design a wordmark for me
- motion_emphasis: tap-to-copy ripple, template field reorder, be creative whenever applicable

## Assistant

_[tool: update_todos]_

_[tool: copy_starter_component]_

_[tool: copy_starter_component]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: snip]_

_[tool: str_replace_edit]_

Let me commit to the design system first.

**Design declaration:**
- Aesthetic: Playful & bright, big rounded cards, springy motion
- Type: **Plus Jakarta Sans** (UI), **JetBrains Mono** (codes/IPs/passwords)
- Palette (dark): bg `oklch(0.18 0.012 175)`, surface `oklch(0.23 0.014 175)`, accents tunable via Tweaks. Default accent: **Mint** `oklch(0.82 0.16 175)`
- Category colors: Work=amber, Personal=violet, Servers=mint
- Motion: spring `cubic-bezier(.34, 1.56, .64, 1)` for snappy overshoot
- Wordmark: stylized "O" with concentric mint dot, "rganote" in Jakarta 700

Now I'll edit the frame for a custom dark bg and start building.

_[tool: snip]_

_[tool: write_file]_

_[tool: write_file]_

_[tool: snip]_

_[tool: write_file]_

_[tool: snip]_

_[tool: write_file]_

_[tool: snip]_

_[tool: write_file]_

_[tool: snip]_

_[tool: write_file]_

_[tool: snip]_

_[tool: write_file]_

_[tool: snip]_

_[tool: done]_

_[tool: save_screenshot]_

_[tool: view_image]_

_[tool: snip]_

_[tool: eval_js]_

_[tool: snip]_

_[tool: fork_verifier_agent]_

Built **Organote** — a hi-fi clickable Android prototype with all 3 main screens plus note viewer, note editor, and template builder.

**Highlights**
- Dark mode, mint accent (tweakable via Tweaks panel: Dark toggle + 5 accent colors)
- Wordmark + categorized note cards with template-colored radial accents
- Server-creds note viewer with **tap-to-copy ripple** + show/hide for passwords + share toast that strips schema
- Editor with **live regex validation** (IP field), debounced auto-save indicator, and generated frontmatter preview
- Template builder with **animated reorder** (springy slide up/down) + bottom-sheet field-type picker showing all 11 field types
- Springy `cubic-bezier(.34,1.56,.64,1)` motion throughout

Open the bottom tab bar to switch screens, tap any note card to view, the FAB to create, and the pencil to edit.

## User

Verifier agent check completed

## Assistant

_[tool: str_replace_edit]_

_[tool: snip]_

_[tool: done]_

_[tool: fork_verifier_agent]_

Fixed the card-overlap bug — note cards now collapse to their proper height.

## User

In the home screen, note list should be more compact. no need to show part of the note. each card should show the note name, last edit, category, tags, pin/favorite button, template name.

Also, in the note view screen, notes can have multiple records so all fields should be part of a single card for a single record. For example, server credentials note will have the following
# Server-1
- Name
- IP
-  url
- username
- password
- os type

# Server-2
- Name
- IP
-  url
- username
- password
- os type

So 2 cards with multiple fields. no need for borders between these fields as they'll be part of a single card.

## Assistant

_[tool: snip]_

_[tool: str_replace_edit]_

_[tool: snip]_

_[tool: str_replace_edit]_

_[tool: snip]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: snip]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: snip]_

_[tool: done]_

_[tool: str_replace_edit]_

_[tool: snip]_

_[tool: done]_

_[tool: fork_verifier_agent]_

Compact note cards now show name, template, category, record count, time, favorite toggle, and tags. Note viewer groups fields by record into a single borderless card per server.

