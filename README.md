# Organote

Local-first structured markdown notes.

## Web Testing

For a normal desktop browser test, build and serve the release web bundle:

```sh
/home/ahmad/flutter/bin/flutter build web
python3 -m http.server 4301 -d build/web
```

Then open `http://127.0.0.1:4301/`.

Avoid using `flutter run -d web-server` as the browser URL for general manual
testing. That mode serves the Dart debug/DDC loader and arbitrary browsers can
sit on a blank page after the DDC module logs. For debug sessions, use
`flutter run -d chrome` so Flutter launches and wires the browser itself.

Organote Web requires real folder access through the File System Access API.
Use desktop Chrome or Edge over HTTPS or localhost. Mobile browsers are blocked
with an explicit unsupported-browser message; use the native Android build for
phone testing.
