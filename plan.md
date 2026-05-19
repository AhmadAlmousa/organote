
## 1. Project Overview

- **Name:** Organote
- **Type:** Cross-platform local-first structured note-taking app using Flutter framework.
- **Target Platforms:** initially Android and Web (PWA)
- **Core Concept:** Organote bridges the gap between unstructured Markdown and structured database records through a template-driven note system. Each note is a typed, schema-validated markdown file containing metadata frontmatter and a structured data block, allowing for strict data entry alongside freeform text.

### Key Value Propositions
- **Local-First:** All user data is stored persistently as real plaintext markdown files and raw binary assets on the user's local device, ensuring instant start-up and full offline capability without proprietary format lock-in. It's critical that notes formatted in a readable and human way. So use conventional markdown formating tools such to indicate sections, rows, etc.
- **Template-Driven:** Users define strict data entry schemas (templates) with typed fields. Notes created from a template are validated against that schema.
- **Cloud-Synced:** Optional bidirectional synchronization with a cloud provider (initially, Google Drive) via a custom 3-way reconciliation engine.
- **Portable:** Robust offline data portability is guaranteed via a full backup and restore mechanism that zips the exact physical directory hierarchy of templates, notes, and assets.


---

## 2. Architectural Design & Core Systems

### Layered Architecture
- **Frontend Framework Paradigm:** Modern, sleek, responsive, appealing, fast, animated, and simple UI framework supporting dynamic theming (Auto, Light, Dark, and OLED pure-black). It must inherently support both Left-to-Right (LTR) and Right-to-Left (RTL) layouts for localization (e.g., English and Arabic), with locale preference persisted in user settings. Don't implement Arabic string in the initial stages.

- **Web Version Frontend:** to take advantage of the screen estate, don't use a mobile navigation bar. Insted, split the screen into 3 parts. opt for a slim side menu to navigate between home, templates, and settings secreen. Based on selected screen, the second section will show relevent content list; so if user navigates to home populate this section with the notes. Third and biggest section should be for content viewer either note, template, or settings. 

### Backend (No-Server Data Layer)
- **Concept:** There is no traditional database server. The user's local filesystem and the remote Cloud Provider API serve as the backend. Notes and templates are stored as markdown files in the selected directory.

### Packages to Consider:
Generally, make sure to use dart MCP server to fetch latest and most popular packages and high scores. Study the following package for implementation whenever applicable
- "gpt_markdown: ^1.1.7": to implement raw rich markdown editor
- "file_picker: ^12.0.0-beta.2"
- "splashscreen: ^2.0.0"
- "emoji_picker_flutter: ^4.4.0": icon selector
- "hijri: ^3.0.0": to convert date and implement dual calendar feature
- "syncfusion_flutter_datepicker: ^33.2.7": dual date picker
- "settings_ui: ^3.0.1": for setting screen
- "flutter_form_builder: ^10.3.0+2": for template builder
- "textfield_tags: ^3.0.1": for tags entry


---

## 3. Storage and File Structures

All user data is stored persistently as plaintext files or raw binary assets within a specific directory hierarchy.

### Storage Hierarchy
The root storage directory contains dedicated subdirectories for templates, notes, assets, and trash. Crucially, category trees for notes act as literal physical folder constructs. Assigning a note to a specific category inherently saves its file under that corresponding directory path. Changing category moves the note file to the new category directory.

### Template Format
Templates are stored as individual human readable markdown files that uses markdown formatting convention to contain:
- **Metadata Frontmatter:** Defines the template identifier, display name, version, preferred layout (e.g., Cards, Table, Grid) for which the associated notes will be displayed in the notes viewer, and an optional selector for default category.

- **Schema Definition:** Details display settings (presets, primary fields), an array of fields (specifying type, label, requirement rules, and type-specific options), and custom actions (like copying a value or opening a URL), and formulas for regex field types.

- **example**: here's an example of how a template should look like:

```
# Template-Name-Goes-Here

## Metadata
- template name: sanitized-name-goes-here
- template ver: 1
- id: 123
- icon: 
- default category: server
- layout: cards

## first-field-name-goes-here
- **type**: text
- **id**: 1
- **required**: false
- **multiline**: false
- **hint**:
- **minlength**: 0
- **maxlength**: 20

## Name
- **type**: text
- **id**: 2
- **required**: true
- **multiline**: false
- **hint**: Person First Name
- **minlength**: 0
- **maxlength**: 20

## ID
- **type**: number
- **id**: 3
- **required**: true
- **hint**: Government ID
- **digits**: 10

## DOB
- **type**: date
- **id**: 4
- **required**: true
- **hint**: Birth date
- **type**: dual
- **primary**: hijri


```

### Note Format
Notes are stored in human readable markdown files adhering markdown formatting conventions to show:
- **Metadata Frontmatter:** Stores primary schema metadata mapping to the note's properties, including the template identifier and version, note identifier, title, icon (emoji), and an array of tags.
- **Structured Data Block:** A custom block parses the concrete instances of template fields as list items or a key-value structure. Multiple records (rows of field values) are supported per note. For example, a noted based on family booklet template will have fields (name, id, dob) for Person-1 as first record, same set of fields for Person-2 as second record. 
- **Unstructured Body:** If the selected template is for freetext or regular markdown it can be stored in this section.
- **example** the note file should show something similar to the following

```
# Note-Title-Goes-Here

## Person-1
- **name**: Ahmad
- **id**: 1020304050
- **dob**: 01-01-2000 | 24-09-1420 H

## Person-1
- **name**: Sarah
- **id**: 2030405060
- **dob**: 01-01-2000 | 24-09-1420 H

---

## Metadata
- template name:
- template ver:
- id:
- icon:
- tags:

```

---

## 4. Template Builder & Field Schemas

The Template Builder allows users to define strict data entry schemas for their notes.

### Presentation & Emoji Integration
- **Layout Modes:** Templates define how their associated notes render in the note viewer,  supporting vertical expandable Cards, data-dense Tables, or adaptive Grids as selected by the user.

- **Universal Emoji Selector:** Integrated throughout the app, allowing users to assign distinct semantic icons to templates, individual notes, and individual input fields. The emoji selector panel includes categories for easy navigation, and if the selected emoji contains a skin tone modifier, it is normalized (flattened) during parsing and storage to ensure consistency across platforms. Also, emoji search box is present with predictive text based on emoji name. Use flutter package "emoji_picker_flutter: ^4.4.0"

### Schema Field Types
The system supports a robust catalog of data constraints, including standard inputs (text, number, date, boolean, dropdown, password, URL, IP address). Each type of these should have relevant set of options for the user to customize the field such as:
* Text field: switch to multi-line textbox toggle
* Number: specify length, or range (min, max).
* * Dropdown: user to input comma-separated list.
* IP Address: ip-formated textbox 4 octets with validation.

In addition to the fields type above, highly specialized fields include:
- **Custom Label Field:** A unique field type utilizing a dynamic label-value pair. It acts as a structural element or informational block. Where the user entered the custom field name and its value during note editing mode. Here's an example for how a custom field would look like within a template markdown file

```
# Template-Name-Goes-Here

## Metadata
- template name: sanitized-name-goes-here
- template ver: 1
- id: 123
- icon: 
- default category: server
- layout: cards

## Server Name
- **type**: text
- **id**: 1
- **required**: true
- **multiline**: false
- **hint**: Server  Name

## field-name-goes-here
- **type**: custom
- **id**: 2
- **required**: true
```

and here's how the note would look like where in this example, the first record has a custom field named vendor while the other has a custom field named serial.

```
# Note-Title-Goes-Here

## Server-1
- **name**: Home Lab
- **vendor**: dell


## Server-2
- **name**: Work Lab
- **serial**: 1a2b3c

---

## Metadata
- template name:
- template ver:
- id:
- icon:
- tags:

```

- **Regex Field:** Enforces specific data structures via custom Regular Expression patterns mapped directly to user-facing hint text constraints.

- **Date Field (Dual Calendar):** Uniquely capable of managing a dual calendar mode, simultaneously recording and rendering both standard Gregorian and Hijri calendars. Values are stored with a suffix indicating the active calendar mode.  i need this field to support single or dual calendars (gregorian and hijri). The user can select Gregorian only, hijri only, or dual. If dual is selected, the user may select which format to for the date picker during note creation and both formats to be displayed in the note viewer.

- **Image Field:** An interactive file-picker field that establishes relative path references to the  local assets storage directory. When creating a note with an image field, once note is saved, store images in a new folder named after the note sanitized title under the assets folder to keep it organized.

### Critical: compliance engine
As users modify a template's schema (adding fields or changing types), the system must note the user existing notes to adhere to the new version by Proactively iterates through local notes against parent templates, yielding metrics and pinpointing specific data gaps or missing mandatory fields. The golden rule is to never modify user data. Instead, a compliance notification is shown on the setting screen. Whenever a note has different set of fields compared to its associated template, user is notified of the change to either update the note content or ignore the notification. When fields are renamed, the old field value is copied to the new key, preserving the legacy data.

---

## 5. Sync Engine & 3-Way Reconciliation

The custom bidirectional Sync Engine maintains true local-first capabilities while interacting with a Cloud Provider API.

### The Sync Ledger
To handle device clock drift gracefully, the engine utilizes a persistent local Sync Ledger. For every synced file, the ledger stores the MD5 checksum of the local file's content at the last sync, the remote cloud file's modification timestamp, and the exact local timestamp of the synchronization.

### Reconciliation Algorithm (6-State Resolution)
During a sync pass, the engine builds manifests of local files, remote files, and the ledger to resolve state through strict cases:
1. **Remote New:** File exists remotely but not locally or in the ledger. Action: Download and create ledger entry.
2. **Local New:** File exists locally but not remotely or in the ledger. Action: Upload and create ledger entry.
3. **Delta Sync & Conflicts:** Checks for local changes (checksum mismatch) or remote changes (modification time is newer than ledger). Conflicts are resolved strictly via Last-Write-Wins using the remote clock.
4. **Local Deletion:** File exists in the ledger and remotely, but is missing locally. Action: Push a soft-delete flag to the cloud and remove the ledger entry.
5. **Remote Deletion:** File exists in the ledger and locally, but is missing remotely. Action: Hard-delete the physical local file and remove the ledger entry.
6. **Deleted Everywhere:** Prune orphaned ledger entries.

*Zombie Exception:* If a remote download request matches a file currently residing in the local soft-delete trash bin, the download is intercepted, and a soft-delete command is actively pushed back to the cloud to "kill the zombie."

### Asset Filtering Strategy
To conserve bandwidth, the sync engine does not blindly synchronize the cloud assets directory. Instead, it uses regular expressions to quickly scan all local markdown file payloads for asset path strings, building a dependency tree, and only downloads binary images actively referenced by existing notes.
- **Asset Naming Convention:** Locally stored assets follow a strict naming convention, for example: `<unix_timestamp_ms>_<sanitized_original_name>`.

---

## 6. UI/UX Workflows & Screen Architectures

### App Initialization
Initialization uses a strict splash screen pattern that blocks the main UI. It requests storage paths and permissions, initializes directory structures and attempts silent cloud re-authentication before rendering the dashboard and starting background syncs with loading progress bar.

### First tab: Home
- **Header:** compact showing only app name on the left and 2 clickable icons on the right for search and compliance notification. The search icon that activates a global search bar that queries metadata and titles entirely in-memory

- **Category:** The horizontal category chips for top-level filtering with number of notes in each category. Last chip shows a pen icon to edit Categories by renaming, deleting, or adding. When deleting a category with notes in it,  ask the user to move the notes to a different category or remove them as well. In the Category editor, the user can specify category color which changes the chip color in the home screen and the note card theme to reflect its category.

- **Note List:** Presents a list of notes dynamically populated from the local repository. The UI is reactive, gracefully re-rendering when background sync events push new data to disk or notes are created or edited. Each note row should should show compact card containing note catgory (upper left corner; matching category color), icon, title, tags chips, last modified (1min, 1h, 1d, 1w, 1mo, 1y, etc), pin icon to pin the note at the top.

- **Floating add button:** to create a new note


#### Notes Creation
- **Header:** Note name and number of fields in the template, save button, cancel button.
- **Note information:** When creating a note, the user will select an icon, enter note name, select category (or add one if desired), enter tags.
- **Records entry:** start with a single record based on the template schema. The user can press "+ Add Record" to keep adding new records accordingly.


#### Notes Viewer & Smart Share Intent
A read-only presentation rendering structured data sequentially.

- **Header:** Note name, last update time, number of records. Menu containing edit button, share button, delete button, edit template, markdown editor to show raw source editor. When sharing a note, a parser intercepts the intent, strips schema data, and compiles a clean, human-readable plain-text buffer to push to the OS share sheet

- **Note body:** show record number, its name then list the keys and values of the record. Each value has tap-to-copy functionality. If the note has images, show thumbnails. Clicking an image pops a scrollable image viewer.

#### Structured Editor vs. Raw Source Editor
- **Structured GUI Editor:** Generates a dynamic visual form bounded by the template schema, handling serialization into frontmatter and data blocks automatically with debounced auto-saving (e.g., a 2-second debounce timer).
  - **Filename Generation:** Note titles are sanitized (lowercased, spaces replaced with underscores, non-alphanumeric characters stripped) to generate safe filenames. Collisions are handled by appending a timestamp suffix.
  - **Navigation & Auto-Save:** Hardware or UI back-button events intercept navigation to ensure unsaved changes are auto-saved before popping. If changing the category or filename, the route is replaced rather than popped to maintain a fresh viewer state.
  - **Tagging:** Includes an autocomplete mechanism that filters existing tags from across the repository.
  - **Category**: show the category selector and allow the user adding new category if it does not exist and specify its color
  - **Universal Emoji Selector**:  use the selector to specify the note icon.
- **Raw Source Editor:** An advanced fallback interface allowing users to edit the underlying markdown, featuring a split-pane markdown renderer for live visual previews and continuous typing auto-save.

### Second tab: Templates
- **Stats Section:** show number of total templates, used templates, unused templates
- **Used Tempalte Section:** each row to show templates with assocaited notes. In the card show template icon, name, number of fields, number of associated notes (clickable to show the notes)

- **Unused Tempalte Section:** each row to show templates without assocaited notes. In the card show template icon, name, number of fields, add button to create an assocaited note.

- **Floating add button:** to create a new tempalte

#### Template Builder screen
- **Template Name:** user enters template name
- **Icon selector:** envoke the emoji picker
- **Template Layout:** User to select how assocaited notes are displayed either in Card, Table, or Grid format.
- **Adding Fields:** first show "+ Add Field" button for the user to select type of field to be added. When a field is added show its properties for the user.
- **Fields:** each field row is collapsable showing the field name and associated properties. The fields should be dragable so the user can sort them if desired.

### Third tab: Settings
- **General note:** While user data lives in markdown files, specific metadata (storage type, UI settings, sync ledger, trash registry, web auth tokens) is strictly kept in a separate local key-value storage system (e.g., SharedPreferences).

- **Sync section:** Google drive sign-in
- **Complinace section:** show current compliance review status based on the compliance engine


- **Data section:** show the following
1- current storage path with change button.
2- Recycle Bin (Soft Delete): Deleted notes are moved to the local trash folder with a 7-day expiration timestamp. Trashed items are flagged remotely rather than hard-deleted.

3- Data Portability:Export workflows compile the physical disk hierarchy into standard ZIP archives, while import workflows restore them, ensuring complete offline data portability.


- **Administration & Danger Zone:** Settings provide a "Change Directory" flow (on native platforms) that physically moves all files to a new path and deletes the old ones. A "Danger Zone" allows users to wipe all local key-value storage, delete all files, and trigger a full application re-initialization.

- **Customization section:** I want to have fun with this one. Let's give the user a fun expereince by enabling advanced customization. First, just show buttons to select theme 'auto, light, dark, or OLED'. Then provide advanced Customization button where the user manupilate many of the app aspects

#### Advanced Customization:
- When selecting non-OLED them, show an color slider to change app accent colors.

Study the following package to provide the user with multiple themes and various app styles
- "google_nav_bar: ^5.0.7"
- "crystal_navigation_bar: ^1.1.0"
- "orient_ui: ^0.7.0"
- "sketchy_design_lang: ^0.4.0"
- "moon_design: ^1.1.0"
- "mix: ^2.0.2"
- "fluent_ui: ^4.15.1"
- "yaru: ^10.1.0"
- "loading_animation_widget: ^1.3.0" to select loading animations for sync process
- "blurrycontainer: ^2.1.0"



---

## 7. Critical Engineering Lessons Learned & Agent Gotchas

This section outlines specific pain points, quirks, and design requirements discovered during development. An AI agent must adhere strictly to these rules to ensure system stability.

1. **Layout Constraints Avoidance:** Never place expansive elements (like flex or expanded widgets) inside unconstrained parent rows or columns. This causes render box assertion failures and results in blank screens.

4. **Stale Data and Cache Invalidation:** Modifying a note flushes changes to disk, but navigating backward may display old data if the UI reflects a stale memory object. Explicit cache invalidation mechanisms must be implemented in the repository layer immediately following a successful disk or cloud save. Navigation events returning to list views must asynchronously trigger data reloads.
5. **Session Persistence & Identity vs. API Authorization:** 

   - **Web Authorization Flow:** Do not confuse simple "Sign in" identity buttons with API authorization flows.
6. **Aggressive Sync Loops on Web Tabs:** Subscribing the Sync Engine to global application focus states is dangerous on the web, triggering massive background syncs every time a tab is clicked. Implement a strong time-based debounce mechanism (e.g., 30 seconds) inside the lifecycle event listener to ignore spurious focus triggers.

8. **COOP Header Blocks on Web:** If a web deployment is served through a reverse proxy with aggressive `Cross-Origin-Opener-Policy` headers, OAuth popups will be blocked. This must be handled via server configuration or graceful error messaging.
9. **Sequential Push Locks:** Rapid note editing can dispatch multiple concurrent sync push calls, creating race conditions and conflicts in the cloud. Implement locks to ensure any new push awaits the completion of the current push before starting.
11. **Non-Blocking Deletion UX:** When a note is deleted from a view screen, trigger the soft-delete operation and background sync sequence, but instantly execute a router pop event to animate the user back to the dashboard gracefully, rather than freezing the screen to await network confirmation.
