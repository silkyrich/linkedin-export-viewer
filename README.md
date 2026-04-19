# linkedin-export-viewer

A static Flutter web app that lets you browse your LinkedIn data-export zip locally in your browser. Your data never leaves the tab.

## What it does

LinkedIn lets you download everything they've collected about you (Settings → Data privacy → Get a copy of your data). The result is a zip full of CSVs that's hard to make sense of. This app unpacks it in-memory and renders it as a mobile-friendly "what LinkedIn stores about you" browser — profile, connections, messages, job applications, ad-targeting segments, and more.

## Privacy model

- **Zero server.** Built as a static site, hosted on GitHub Pages.
- **Your zip stays in your browser.** Parsing happens in a Web Worker on your device. Nothing is uploaded.
- **Cache opt-in.** The archive is cached in IndexedDB so a refresh doesn't make you re-upload. A visible "Clear Data" button wipes it.
- **Demo mode.** Try it without your own zip — there's a "Try demo data" button that loads synthetic, obviously-fake fixtures.

## Status

Live at https://silkyrich.github.io/linkedin-export-viewer/. All 9 export categories have dedicated screens, plus a message-flow timeline graph with filters, global search, dark mode, drag-and-drop upload, and deep-links back into LinkedIn. See [`docs/PLAN.md`](./docs/PLAN.md) for the full roadmap.

## Development

Requires Flutter stable (3.38+).

```bash
flutter pub get
flutter run -d chrome
```

### Regenerating synthetic fixtures

```bash
dart run tool/generate_fixture.dart
```

Produces `fixtures/sample_export/` and `fixtures/sample_export.zip`. Seeded (`Random(42)`) so output is deterministic and diff-friendly.

### Building for GitHub Pages

```bash
flutter build web --release --base-href "/linkedin-export-viewer/" --pwa-strategy=none
dart compile js lib/services/worker/parse_worker.dart -o build/web/worker.dart.js -O2
touch build/web/.nojekyll
```

## License

MIT — see [`LICENSE`](./LICENSE). Not affiliated with LinkedIn. "LinkedIn" is a trademark of LinkedIn Corporation; the schema names and CSV column headers used by this viewer come from the export LinkedIn provides to its own members.
