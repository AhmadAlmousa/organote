# Organote

Organote is a local-first Flutter notes app for structured Markdown libraries.
It stores user data as plain files in a folder the user chooses, then layers
templates, validation, search, backup, trash, and optional Google Drive sync on
top of that portable file tree.

## Highlights

- Local-first storage with no required server or database.
- User-selected storage folder on first launch.
- Plain Markdown notes and templates that remain readable outside the app.
- Template-driven structured records with typed fields.
- Categories stored as real note folder paths.
- Tags, pins, favorites, search, and category browsing.
- Image fields with assets copied into the library.
- Raw Markdown source editor for direct file-level fixes.
- Compliance scans for template drift, missing fields, type mismatches, orphaned
  template references, and rename-copy suggestions.
- Soft-delete trash with restore and purge flows.
- Zip backup export and restore.
- Optional Google Drive sync using the Drive API and a sync ledger.
- Android and desktop web support.

## How It Works

Organote treats the filesystem as the source of truth. On first launch, the app
asks the user to pick a storage folder. It then creates this structure:

```text
Organote/
  templates/
  notes/
  assets/
  trash/
  .organote/
```

Templates define structured fields. Notes reference templates and store records
as Markdown plus metadata. Categories map to physical folders under `notes/`, so
moving a note between categories is also a file move.

Google Drive sync is optional. When connected, the app builds local and remote
manifests, compares them with `.organote/sync_ledger.json`, and reconciles
uploads, downloads, deletions, and conflicts. The sync scope is intentionally
limited to `drive.file`.

## Field Types

Templates can use these field types:

- Text
- Number
- Date
- Boolean
- Dropdown
- Password
- URL
- IP address
- Regex
- Image
- Custom label

Template layouts can be cards, table, or grid.

## Requirements

- Flutter SDK
- Android SDK for Android builds
- Desktop Chrome or Edge for web folder access
- A Google Cloud project only if Google Drive sync is enabled

## Getting Started

Install dependencies:

```sh
/home/ahmad/flutter/bin/flutter pub get
```

Create a local environment file:

```sh
cp .env.example .env
```

Then edit `.env` with your Google OAuth client IDs if you plan to use Drive
sync. The file is ignored by Git.

Run on Android:

```sh
/home/ahmad/flutter/bin/flutter run
```

Run on Chrome for debugging:

```sh
/home/ahmad/flutter/bin/flutter run -d chrome
```

For a normal browser test of the release web bundle:

```sh
/home/ahmad/flutter/bin/flutter build web
python3 tools/serve_web.py --port 4301 --directory build/web
```

Use `tools/serve_web.py` instead of plain `python3 -m http.server` for Google
Drive sync testing. It adds `Cross-Origin-Opener-Policy:
same-origin-allow-popups`, which Google Sign-In popup flows require on the app
HTML response.

If you are testing Google Drive sync in the browser, first add your Web OAuth
client ID to `web/index.html`:

```html
<meta name="google-signin-client_id" content="<WEB_CLIENT_ID>">
```

Flutter web does not load `.env` at runtime; deployment servers and proxies
commonly block dotfiles.

In the web settings screen, use the Google-rendered sign-in button first, then
press the Drive authorize button to grant the `drive.file` scope.

Then open:

```text
http://127.0.0.1:4301/
```

Avoid using `flutter run -d web-server` as the browser URL for general manual
testing. That mode serves the Dart debug loader and arbitrary browsers can sit
on a blank page after the debug module logs. For debug sessions, use
`flutter run -d chrome`.

## Platform Notes

### Android

Android uses native file storage and the system folder picker. The app package
name is currently:

```text
com.example.organote
```

Change `applicationId` in `android/app/build.gradle.kts` before publishing a
real app.

### Web

Organote Web requires the File System Access API. Use desktop Chrome or Edge
over HTTPS or `localhost`. Mobile browsers are blocked with an explicit
unsupported-browser message; use the native Android build for phone testing.

## Google Drive Sync Setup

The app already includes the Drive sync implementation and the Settings > Sync >
Connect Drive action. To activate it:

1. Open Google Cloud Console.
2. Create or select a project.
3. Enable the Google Drive API.
4. Configure the OAuth consent screen.
5. Add this OAuth scope:

```text
https://www.googleapis.com/auth/drive.file
```

6. Create an Android OAuth client for the app package name.
7. Create a Web application OAuth client in the same project.
8. Add that Web application OAuth **Client ID** to `web/index.html` for
   browser Drive sync:

```html
<meta name="google-signin-client_id" content="<WEB_CLIENT_ID>">
```

9. Add that same Web application OAuth **Client ID** to `.env` for native
   Android Google Sign-In:

```env
GOOGLE_SIGN_IN_WEB_CLIENT_ID=<WEB_CLIENT_ID>
GOOGLE_SIGN_IN_CLIENT_ID=
GOOGLE_SIGN_IN_SERVER_CLIENT_ID=
```

Google Cloud Console labels this value as `Client ID`. The Android
`google_sign_in` plugin uses that same Web OAuth client ID as its
`serverClientId`.

After `.env` is configured, native run and build commands will read it:

```sh
/home/ahmad/flutter/bin/flutter run
/home/ahmad/flutter/bin/flutter build apk
```

The Web OAuth client must include every browser origin you will use under
**Authorized JavaScript origins**, for example:

```text
https://dev2.tnl.almou.sa
http://localhost:8080
```

If the browser reports a closed Google authorization popup, verify that the
origin is listed exactly and that the browser or reverse proxy is not blocking
popups from the app page. The public app response must include:

```http
Cross-Origin-Opener-Policy: same-origin-allow-popups
```

Check the effective tunneled response with:

```sh
curl -I https://dev2.tnl.almou.sa/
```

Web builds can also accept
`--dart-define=GOOGLE_SIGN_IN_WEB_CLIENT_ID=<WEB_CLIENT_ID>`, but the preferred
web configuration is the Google plugin meta tag.

If you use a separate server client ID, set it too:

```env
GOOGLE_SIGN_IN_WEB_CLIENT_ID=<WEB_CLIENT_ID>
GOOGLE_SIGN_IN_CLIENT_ID=
GOOGLE_SIGN_IN_SERVER_CLIENT_ID=<SERVER_CLIENT_ID>
```

The `.env` file is bundled into native app builds. OAuth client IDs are not
private keys, but do not commit real project-specific IDs, private keystores,
service-account files, signing passwords, or other secrets.

This Android project does not currently include `google-services.json`, so the
Web OAuth client ID must be available to native Android builds as
`GOOGLE_SIGN_IN_WEB_CLIENT_ID` or `GOOGLE_SIGN_IN_CLIENT_ID`.
The Android OAuth client in Google Cloud must also match the package name
(`com.example.organote` by default) and the SHA-1 for the build you are running.

Settings > Diagnostics > Save error log writes caught errors to
`.organote/errors.log` inside the selected storage folder. Caught errors are
also written to the runtime console, including the browser console on web.

## Android SHA-1 Fingerprints

Google Sign-In needs Android OAuth clients whose package name and SHA-1 match
the build you are running.

Get debug and configured release fingerprints:

```sh
cd android
./gradlew signingReport
```

Look for:

```text
Variant: debug
SHA1: AA:11:BB:22:CC:33:DD:44:EE:55:FF:66:00:77:88:99:AA:BB:CC:DD

Variant: release
SHA1: 11:AA:22:BB:33:CC:44:DD:55:EE:66:FF:77:00:88:99:BB:AA:DD:CC
```

The values above are scrambled examples. Use the real values printed by your
local signing report.

For a real release/upload keystore:

```sh
keytool -list -v \
  -keystore /path/to/upload-keystore.jks \
  -alias your_alias
```

If publishing through Google Play App Signing, also add the SHA-1 from:

```text
Google Play Console > Setup > App integrity > App signing certificate
```

During development this project may sign `release` with the debug key. Configure
a real release signing config before distributing builds.

## Storage And Data Portability

Because notes, templates, and assets are ordinary files, a user can back up,
inspect, move, or version the library folder outside Organote. App metadata such
as the sync ledger, trash index, and category metadata lives under `.organote/`.

Backups are exported as zip files containing the same library structure.

## Testing

Run all tests:

```sh
/home/ahmad/flutter/bin/flutter test
```

Run static analysis:

```sh
/home/ahmad/flutter/bin/flutter analyze
```

Useful focused tests:

```sh
/home/ahmad/flutter/bin/flutter test test/ui/splash_screen_test.dart
/home/ahmad/flutter/bin/flutter test test/services/sync/google_drive_sync_repository_test.dart
```

## Project Layout

```text
lib/
  data/        Markdown codec, validation, and local repositories
  domain/      Core models and repository contracts
  services/    Storage, sync, compliance, and backup services
  ui/          Flutter screens, widgets, state, and theme
web/           Web filesystem bridge and Flutter web shell
android/       Android project and Gradle configuration
test/          Unit and widget tests
```

## Security Notes

- Organote data is stored as plaintext files in the chosen folder.
- Google Drive sync uses `drive.file`, not full-drive access.
- Do not commit real signing keys, keystores, passwords, or downloaded private
  credential files.
- Keep public documentation examples redacted or synthetic.
