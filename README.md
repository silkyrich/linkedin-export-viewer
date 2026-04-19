# LinkedOut!

A static Flutter web app that lets you browse your LinkedIn data-export zip locally in your browser. Your data never leaves the tab.

**Live:** https://silkyrich.github.io/linkedin-export-viewer/

> The GitHub repo is still called `linkedin-export-viewer` for URL stability (it's the GH Pages subpath). The *product* is LinkedOut!.

## What it does

LinkedIn lets you download everything they've collected about you (Me → Settings → Data privacy → Get a copy of your data). The result is a zip full of CSVs that's hard to make sense of. LinkedOut! unpacks it in-memory and renders it as a mobile-friendly "what LinkedIn stores about you" browser.

**Ten tabs:**

| Tab | What it covers |
|---|---|
| **You** *(your first name)* | Profile, summary, registration, emails, phones, languages |
| **Insights** | Cross-cutting dashboard: headline counts, top companies in your network, top correspondents, spend totals, longest tenure |
| **Network** | Connections, Companies roll-up, Invitations, Recommendations, Endorsements |
| **Messages** | Every DM with filters for direction (sent / received / no reply), date range, and search |
| **Career** | Positions with career-summary stats, Job Applications with per-month volume, Saved Jobs, Preferences |
| **Learning** | Course history + Articles rendered in sandboxed iframes |
| **Skills** | Declared skills, education, identity verifications |
| **Content** | Publications, projects, rich media |
| **Activity** | Company follows, events |
| **Account** | Receipts with spend totals + payment-method breakdown, ad-targeting segments |
| **Advisor** | Export a Markdown dossier with preset prompts, or opt in to a direct LLM review with your own API key (OpenAI, Anthropic, Gemini, Ollama) |

## Privacy model

- **Zero server.** Built as a static site, hosted on GitHub Pages.
- **Your zip stays in your browser.** Parsing happens on the main thread with per-file yields; nothing is uploaded.
- **Cache opt-in.** The archive bytes are cached in IndexedDB so a refresh doesn't make you re-upload. A "Clear data" button in the banner wipes it.
- **Demo mode.** Try it without your own zip — the "Try with sample data" button loads a synthetic, obviously-fake fixture featuring Ada Lovelace and ten Victorian correspondents.
- **Advisor LLM calls are opt-in.** Two paths: (1) copy the Markdown dossier into any LLM you already trust (nothing leaves the tab); (2) opt in to a direct browser-origin API call to OpenAI/Anthropic/Gemini/Ollama with your own key. Your key is only stored if you tick "remember key", and then only in IndexedDB.

## Development

Requires Flutter stable (3.41+).

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
touch build/web/.nojekyll
```

The CI workflow at `.github/workflows/deploy.yml` runs this on every push to `main`.

## License

MIT — see [`LICENSE`](./LICENSE). Not affiliated with LinkedIn. "LinkedIn" is a trademark of LinkedIn Corporation; the schema names and CSV column headers used by this viewer come from the export LinkedIn provides to its own members.
