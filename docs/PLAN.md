# linkedin-export-viewer — Implementation Plan

## Context

Greenfield Flutter web app at `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/` that lets a user upload their LinkedIn data export zip and browse "what LinkedIn stores about you" on any device. All parsing happens in the browser — **no server, no uploads, no tracking**. Deployed as static files on GitHub Pages.

The real export we inspected contains ~30 CSV files across 9 logical categories (Me, Network, Messages, Career, Learning, Skills & Education, Content, Activity, Account) plus subfolders (`Articles/` HTML, `Jobs/`, `Verifications/`). The hardest file by far is `messages.csv` — **22,557 rows, 2.6MB** — which rules out naïve main-thread parsing on mobile.

**User decisions locked in:**
- **Messages-first build order** — ship the hard problem (Web Worker + virtualized list) before the easy screens.
- **IndexedDB caching** — archive survives reloads; user can "clear data" to wipe.
- **Articles rendered in sandboxed iframes** (`srcdoc` + `sandbox` attrs) to preserve formatting safely.
- **PII never committed** — `.gitignore` blocks `Basic_LinkedInDataExport_*` and `*.csv`. Real export at `Basic_LinkedInDataExport_04-17-2026.zip/` is local dev reference only.
- **Synthetic fixtures** — a committed Dart generator (`tool/generate_fixture.dart`) emits a realistic-size fake export (~20k synthetic messages, obviously-fake names/emails/companies) under `fixtures/sample_export/` + zipped to `fixtures/sample_export.zip`. Both script and output are committed.
- **Demo mode** — deployed landing page has a "Try with sample data" button that fetches `fixtures/sample_export.zip` as a static asset and pipes it through the normal upload flow. Removes the "bring your own zip" barrier for first-time visitors.

## Project layout

```
lib/
  main.dart                      # runApp + HashUrlStrategy + router
  app.dart                       # MaterialApp.router, M3 theme, ResponsiveShell
  core/
    constants.dart               # category defs, filename->category map
    result.dart                  # sealed Result<T> / ParseWarning types
  models/
    archive.dart                 # LinkedInArchive { files: Map<String, ParsedFile> }
    parsed_file.dart             # { path, headers, rows, warnings, isEmpty }
    category.dart                # enum + icon/label metadata
    entities/                    # typed views for Me/Connections/Messages/Positions
      profile.dart
      connection.dart
      message.dart                # id, conversationId, from, to, date, content, folder, isDraft
      position.dart
  services/
    archive_loader.dart          # file_picker -> bytes -> worker -> controller
    cache_service.dart           # IndexedDB read/write of zip bytes (key: "archive_v1")
    csv_service.dart             # csv package wrapper (shouldParseNumbers: false, multiline)
    worker/
      parse_worker.dart          # SEPARATE DART ENTRYPOINT, compiled to worker.dart.js
      protocol.dart               # {kind, payload} JSON messages shared main <-> worker
  state/
    archive_controller.dart      # Riverpod AsyncNotifier<LinkedInArchive>
    selectors.dart               # derived providers (meProvider, messagesProvider, ...)
    messages_index.dart          # in-memory index: conversationId -> List<int> row offsets
  router/
    app_router.dart              # go_router, hash strategy, redirect when archive is null
    routes.dart
  ui/
    shell/
      responsive_shell.dart      # NavigationBar (<600) | NavigationRail (600-1024) | Drawer (>1024)
      privacy_banner.dart        # "your data stays in this browser" + Clear Data button
    screens/
      landing_screen.dart        # drop zone, explainer, privacy pitch, "Try demo data" button
      loading_screen.dart        # per-file progress from worker events
      messages_screen.dart       # virtualized, grouped by conversation, searchable  [PHASE 1]
      me_screen.dart
      network_screen.dart
      career_screen.dart
      learning_screen.dart       # Learning.csv + Articles iframe viewer
      skills_education_screen.dart
      content_screen.dart
      activity_screen.dart
      account_screen.dart        # Receipts + Ad_Targeting (handles duplicate column names)
      raw_file_screen.dart       # generic CSV fallback
    widgets/
      kv_table.dart
      csv_table.dart             # virtualized via two_dimensional_scrollables
      message_row.dart
      empty_state.dart
      search_field.dart
      article_frame.dart         # HtmlElementView wrapping sandboxed iframe (srcdoc)
web/
  index.html                     # keep <base href="$FLUTTER_BASE_HREF"> + .nojekyll
  worker.dart.js                 # BUILD OUTPUT — generated, gitignored
  assets/
    sample_export.zip            # copied from fixtures/ at build time; served as static asset
tool/
  generate_fixture.dart          # produces fixtures/sample_export/ + .zip
fixtures/
  sample_export/                 # ~30 synthetic CSVs mirroring real schema
  sample_export.zip              # zipped form, loaded by "Try demo" button
test/
  fixtures_smoke_test.dart       # sanity-check generator output schema
.github/workflows/deploy.yml
```

## Package choices

| Purpose | Package | Why |
|---|---|---|
| File picking (web) | `file_picker` ^8 | Returns `Uint8List` without dart:io; web-safe. |
| Zip decode | `archive` ^3 | Pure-Dart, runs in worker context fine. |
| CSV parsing | `csv` ^6 | Handles multi-line quoted fields. Configure `shouldParseNumbers: false`. |
| State | `flutter_riverpod` ^2.5 | `AsyncNotifier` maps cleanly to loading/loaded/error; cheap `ConsumerWidget` reads. |
| Routing | `go_router` ^14 | Declarative, deep-linkable, works with hash URL strategy. |
| Virtualized tables | `two_dimensional_scrollables` ^0.3 | `TableView.builder` — handles 22k rows without materializing widgets. |
| Dates | `intl` | Message/position date formatting. |
| IndexedDB | `idb_shim` ^2 | Clean cross-browser IndexedDB API for caching raw zip bytes. |
| URL strategy | `flutter_web_plugins` (SDK) | `setUrlStrategy(HashUrlStrategy())` for GH Pages. |

## State flow

1. `LandingScreen` (or auto-load from cache on boot) → calls `ref.read(archiveControllerProvider.notifier).loadFromBytes(bytes)`.
2. `ArchiveController` (`AsyncNotifier<LinkedInArchive>`) posts bytes to the Web Worker via `html.Worker.postMessage(bytes, [bytes.buffer])` (zero-copy transfer).
3. Worker unzips, iterates entries, parses each CSV, posts `{kind: "file", path, headers, rows}` messages back. On completion posts `{kind: "done"}`.
4. Controller accumulates into `LinkedInArchive`, emits `AsyncValue.data(archive)`. Also writes the raw zip bytes to IndexedDB via `CacheService.save(bytes)`.
5. Screens are `ConsumerWidget`s reading narrow selectors (`meProvider`, `messagesProvider`). Leaf widgets stay `StatelessWidget` with plain data in, easy to unit-test.
6. On app start, `main.dart` checks `CacheService.load()` — if bytes exist, push straight into the controller and skip `LandingScreen`. Privacy banner always visible with "Clear Data" → wipes IndexedDB + resets state.

## Synthetic fixtures (`tool/generate_fixture.dart`)

A pure-Dart generator (`dart run tool/generate_fixture.dart`) produces a **realistic, obviously-fake** LinkedIn export so the repo has test data, Ultraplan/CI have context, and the deployed site has a demo mode.

**Design rules:**
- **Obviously fake.** Names from a seeded pool of historical figures (Ada Lovelace, Grace Hopper, Alan Turing, …). Emails at `@example.com`. Phones in the `555-01xx` reserved range. Companies named after fictional ones ("Cyberdyne Systems", "Initech", "Umbraco Corp", …). Nothing resembling a real person.
- **Schema-faithful.** Column headers and file names match the real export byte-for-byte, including quirks: duplicate columns in `Ad_Targeting.csv`, empty data rows in `guide_messages.csv`, multi-line quoted fields in `messages.csv`, `Articles/Articles/*.html` nested path.
- **Realistic scale.** `messages.csv` emits **~20,000 rows** across ~200 synthetic conversations with varied lengths (1–400 messages), reply threading, occasional drafts. `Connections.csv` ~2,000 rows. Other files match real row counts (~30 endorsements, ~10 positions, etc.).
- **Seeded RNG** (`Random(42)`) so output is deterministic — commits stay diff-friendly.
- **Outputs two artifacts:**
  1. `fixtures/sample_export/` — unpacked CSVs + subfolders, browsable in the repo.
  2. `fixtures/sample_export.zip` — zipped via the `archive` package so it matches what a user would upload.
- **Build step copies the zip** to `build/web/assets/sample_export.zip` (also listed in `pubspec.yaml` under `flutter: assets:` so `rootBundle.load()` works in dev).
- **Demo flow:** `LandingScreen` "Try demo data" button → `rootBundle.load('assets/sample_export.zip')` → feed bytes into the same `archiveControllerProvider.loadFromBytes(...)` path as a real upload. Identical code path; no "demo mode" branching past the landing screen.
- **Repo size budget:** ~2–3 MB for `sample_export.zip`, ~3–4 MB unzipped. Acceptable. If it grows, we can switch to committing only the zip and generating the unpacked dir on demand.

## Parsing strategy (the hard part — Phase 1 focus)

Flutter web's `compute()` runs on the main thread (no true isolates), so the 22k-row messages parse would freeze the UI. We use a **real Web Worker**:

- `lib/services/worker/parse_worker.dart` is a **separate Dart entrypoint**. Compiled via `dart compile js lib/services/worker/parse_worker.dart -o web/worker.dart.js` as part of the build.
- Main thread: `final worker = html.Worker('worker.dart.js'); worker.postMessage(bytes, [bytes.buffer]);`
- Worker: unzips with `archive`, then for each CSV entry, streams rows in batches of 500 back to main thread (`worker.postMessage({'kind': 'rows', 'path': p, 'batch': [...]})`). This gives incremental progress updates for the loading screen.
- `messages.csv` specifically: worker builds a compact `List<Message>` + a `Map<String, List<int>>` of conversationId → row indices, then posts both. Main thread never re-parses.
- `MessagesScreen` uses `TableView.builder` with a scroll controller bound to conversation boundaries; search filters the index, not the list.

**Fallback if worker compilation is too painful in CI:** chunked main-thread parse with `await Future.delayed(Duration.zero)` between files. Acceptable for everything except messages — but we committed to Messages-first, so the worker is non-negotiable.

## Navigation

- `ResponsiveShell` via `LayoutBuilder`:
  - Width `< 600`: `NavigationBar` with 5 tabs (Me, Network, Messages, Career, More). "More" → list of Learning, Skills, Content, Activity, Account.
  - Width `600–1024`: `NavigationRail` with all 9.
  - Width `> 1024`: persistent `Drawer` + rail.
- Routes (go_router): `/`, `/loading`, `/messages`, `/messages/:conversationId`, `/me`, `/network`, `/career`, `/learning`, `/learning/article/:filename`, `/skills`, `/content`, `/activity`, `/account`, `/raw/:path`.
- `HashUrlStrategy()` so GitHub Pages doesn't 404 on refresh.
- Router redirect: if archive is null AND no cached archive, force to `/`.

## GitHub Pages deployment

- Build: `flutter build web --release --base-href "/linkedin-export-viewer/" --pwa-strategy=none`.
- Post-build step: `dart compile js lib/services/worker/parse_worker.dart -o build/web/worker.dart.js -O2`.
- Add empty `build/web/.nojekyll` so Pages doesn't strip underscore-prefixed build assets.
- `.github/workflows/deploy.yml`:
  - Trigger: push to `main`.
  - Steps: checkout → `subosito/flutter-action@v2` (pin `channel: stable`) → `flutter pub get` → build web → compile worker → `peaceiris/actions-gh-pages@v3` publishing `build/web` to `gh-pages` branch.
- Enable Pages in repo settings (source: `gh-pages` branch, `/`).
- `web/index.html` keeps `<base href="$FLUTTER_BASE_HREF">` token untouched.

## Phased build order (Messages-first per your call)

**Phase -1 — Bootstrap + check in what we have:**
- Copy this plan to `docs/PLAN.md` inside the repo so it ships with the code and is visible to remote tooling (Ultraplan, CI, collaborators).
- First commit: `.gitignore` + `docs/PLAN.md`. Push to `main`.

**Phase 0 — Fixtures (do first so everything else has test data):**
0a. Scaffold Flutter project, `pubspec.yaml` deps, `analysis_options.yaml`. Commit + push.
0b. Write `tool/generate_fixture.dart` + `test/fixtures_smoke_test.dart`.
0c. Run generator, commit `fixtures/sample_export/` + `fixtures/sample_export.zip`. Push.
0d. Verify against the 9-category schema; tweak generator until schema matches real export.
0e. **Re-run Ultraplan** pointed at the repo (it can now read `docs/PLAN.md` and inspect `fixtures/sample_export/`) to pressure-test the plan against concrete schema-faithful data. Integrate its feedback before starting Phase 1.

**Phase 1 — Pipeline + Messages (the hard stuff, built against fixtures):**
1. `archive.dart`, `parsed_file.dart`, `message.dart` models.
2. Worker entrypoint + protocol + `dart compile js` build script.
3. `archive_loader.dart`, `archive_controller.dart`.
4. `cache_service.dart` (IndexedDB roundtrip of raw zip bytes).
5. `LandingScreen` (upload + "Try demo data" button wiring `rootBundle.load('assets/sample_export.zip')`), `LoadingScreen`, privacy banner, Clear Data action.
6. `MessagesScreen` with virtualized `TableView`, conversation grouping, search over index. Validate against the 20k synthetic rows from Phase 0.
7. `ResponsiveShell` + router skeleton.
8. GitHub Action + Pages deploy (copies `fixtures/sample_export.zip` → `build/web/assets/`).
9. **Milestone: visitor hits GH Pages → clicks "Try demo" → sees the full Messages viewer with 20k synthetic messages, OR uploads their own zip.**

**Phase 2 — Easy screens:**
11. Me, Network (Connections + Recommendations + Endorsements + Invitations).
12. Skills & Education, Content, Activity.
13. `raw_file_screen.dart` fallback for anything unhandled.

**Phase 3 — Remaining depth:**
14. Career (Positions + Jobs/* + SavedJobAlerts).
15. Learning (Learning.csv + Articles iframe viewer via `HtmlElementView` + `srcdoc`/`sandbox`).
16. Account (Receipts, Ad_Targeting with positional column handling for duplicate headers).

**Phase 4 — Polish + stretch visualizations:**
17. Global search across archive (tokenized index in worker).
18. Empty-state polish, mobile tap targets, keyboard nav on desktop.
19. File size warning on pick (>50MB prompt).
20. **Message-flow timeline graph** (`lib/ui/screens/network_flow_screen.dart`) — force-directed contact graph rendered via `CustomPainter` with an `AnimationController`-driven timeline scrubber. Pre-compute a `List<(DateTime, from, to)>` index (already in memory from Phase 1), run force layout **once** at mount (or via `graphview` / a tiny custom Verlet sim), then animate particles along fixed edges as the scrubber advances. Node radius/opacity encodes rolling message volume. Play/pause, speed slider, date-range filter. Feasibility: ~200 nodes / a few hundred edges is comfortable for Skia on desktop and mid-tier mobile at 60fps, provided we never re-layout per frame — only re-paint. Risk: force-sim convergence jitter on low-end devices; mitigate by capping iterations and caching the final node positions in IndexedDB alongside the archive.

## Critical files

- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/pubspec.yaml`
- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/tool/generate_fixture.dart`
- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/fixtures/sample_export.zip`
- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/lib/main.dart`
- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/lib/services/worker/parse_worker.dart`
- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/lib/services/archive_loader.dart`
- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/lib/services/cache_service.dart`
- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/lib/state/archive_controller.dart`
- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/lib/ui/screens/messages_screen.dart`
- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/lib/router/app_router.dart`
- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/.github/workflows/deploy.yml`
- `/Users/richardmorgan/Documents/GitHub/linkedin-export-viewer/web/index.html`

## Verification

**Phase 0 exit criteria:**
- `dart run tool/generate_fixture.dart` produces `fixtures/sample_export/` + `fixtures/sample_export.zip` deterministically (re-running yields identical bytes).
- `dart test test/fixtures_smoke_test.dart` passes: every expected filename present, headers match real schema, row counts within expected ranges, Articles HTML files exist.
- Visual spot-check: open a few generated CSVs, confirm obviously-fake names, no stray real data.

**Phase 1 exit criteria:**
1. `flutter run -d chrome` → landing screen renders, both "Upload zip" and "Try demo data" work (demo loads the bundled fixture; upload accepts a real LinkedIn zip).
2. Loading screen shows per-file progress from worker.
3. MessagesScreen scrolls smoothly through all 22k rows on a Chrome desktop (no jank >16ms frames) and on a mobile viewport (Chrome DevTools device toolbar, mid-tier Android preset).
4. Refreshing the page reloads the archive from IndexedDB without re-picking. "Clear Data" wipes it.
5. `flutter build web --release --base-href "/linkedin-export-viewer/"` succeeds; serving `build/web/` locally (`python3 -m http.server` from that dir, adjusted for base-href) renders correctly.
6. Push to `main` → GH Action runs green → `https://<user>.github.io/linkedin-export-viewer/` loads; upload works; messages render; reload keeps the archive.
7. Git status confirms no CSVs or export folders are tracked (smoke check: `git check-ignore Basic_LinkedInDataExport_04-17-2026.zip/messages.csv` returns the path).

**Subsequent phase checks** add the relevant screens and repeat steps 1/6 for each category.
