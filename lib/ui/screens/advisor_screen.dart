import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/downloads_stub.dart'
    if (dart.library.js_interop) '../../core/downloads_web.dart';
import '../../services/dossier_builder.dart';
import '../../state/archive_controller.dart';
import '../../state/flow_index.dart';
import '../widgets/empty_state.dart';

/// "Export for an AI" screen: generates a Markdown dossier the user can
/// paste into any LLM of their choice (ChatGPT, Claude, Gemini, local
/// Ollama). Nothing is sent from this app — we only build the text and
/// hand it to the clipboard or a file download.
class AdvisorScreen extends ConsumerStatefulWidget {
  const AdvisorScreen({super.key});

  @override
  ConsumerState<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends ConsumerState<AdvisorScreen> {
  AdvisorPrompt _prompt = AdvisorPrompt.careerAdvisor;
  bool _anonymize = true;
  bool _includeContacts = false;

  @override
  Widget build(BuildContext context) {
    final archive = ref.watch(archiveControllerProvider).valueOrNull;
    if (archive == null) {
      return const EmptyState(message: 'No archive loaded.');
    }
    final flow = ref.watch(flowIndexProvider);

    final options = DossierOptions(
      prompt: _prompt,
      anonymizeContacts: _anonymize,
      includeTopContactSummaries: _includeContacts,
    );
    final result = buildDossier(archive, flow, options);

    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _intro(theme),
        const SizedBox(height: 16),
        _promptPicker(theme),
        const SizedBox(height: 16),
        _optionsCard(theme),
        const SizedBox(height: 16),
        _preview(context, theme, result),
      ],
    );
  }

  Widget _intro(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assistant_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Export for an AI advisor', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'We don\'t call any AI from here. Your archive still never '
              'leaves this tab. This page just assembles a clean Markdown '
              'dossier you can paste into whichever LLM you already trust '
              '— ChatGPT, Claude, Gemini, a local model, whatever — with a '
              'prompt pre-written for the kind of feedback you want.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _promptPicker(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What would you like the AI to do?',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in AdvisorPrompt.values)
                  ChoiceChip(
                    label: Text(p.title),
                    selected: _prompt == p,
                    onSelected: (_) => setState(() => _prompt = p),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionsCard(ThemeData theme) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Anonymize contact names'),
            subtitle: const Text(
              'Replaces correspondent names with initials so your network '
              'isn\'t handed to an LLM provider.',
            ),
            value: _anonymize,
            onChanged: (v) => setState(() => _anonymize = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Include top correspondents (aggregate only)'),
            subtitle: const Text(
              'Adds a Top correspondents section with message counts. '
              'Never includes message bodies.',
            ),
            value: _includeContacts,
            onChanged: (v) => setState(() => _includeContacts = v),
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context, ThemeData theme, DossierResult result) {
    final kb = (result.bytes / 1024).toStringAsFixed(1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Preview', style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                Text(
                  '· $kb KB${result.truncated ? ' · truncated' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => downloadTextFile(
                    'linkedin-dossier-${_prompt.name}.md',
                    result.markdown,
                  ),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download .md'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: result.markdown),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Dossier copied. Paste into your LLM.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 480),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: SelectableText(
                  result.markdown,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
