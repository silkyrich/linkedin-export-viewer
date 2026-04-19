import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/downloads_stub.dart'
    if (dart.library.js_interop) '../../core/downloads_web.dart';
import '../../services/dossier_builder.dart';
import '../../services/llm_client.dart';
import '../../services/profile_reviewer.dart';
import '../../state/archive_controller.dart';
import '../../state/flow_index.dart';
import '../../state/llm_settings.dart';
import '../widgets/empty_state.dart';

/// "Advisor" — two paths:
///   1. Export a prompt-prefixed Markdown dossier to paste into any LLM
///      you already trust (no API call; nothing leaves the tab).
///   2. (Opt-in) Send the dossier directly to an LLM you choose, with a
///      key you supply, and render an anchored, structured career review.
class AdvisorScreen extends ConsumerStatefulWidget {
  const AdvisorScreen({super.key});

  @override
  ConsumerState<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends ConsumerState<AdvisorScreen> {
  AdvisorPrompt _prompt = AdvisorPrompt.careerAdvisor;
  bool _anonymize = true;
  bool _includeContacts = false;

  bool _reviewing = false;
  ProfileReview? _review;
  String? _reviewError;

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
        const SizedBox(height: 24),
        _llmSection(context, theme, result.markdown),
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
                Text('Advisor', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Two paths. Either copy a clean Markdown dossier and paste it '
              'into whichever LLM you already use — no API call from here, '
              'your archive still never leaves this tab. Or, further down '
              'the page, you can opt in to calling an LLM directly with '
              'your own API key; that specific dossier goes to that '
              'specific provider and the structured response comes back '
              'anchored to your profile.',
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
                Text('Dossier preview', style: theme.textTheme.titleMedium),
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
              constraints: const BoxConstraints(maxHeight: 320),
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

  // -------------------------------------------------------------
  // Direct LLM call (opt-in)

  Widget _llmSection(BuildContext context, ThemeData theme, String dossier) {
    final llm = ref.watch(llmSettingsProvider);
    final llmCtrl = ref.read(llmSettingsProvider.notifier);

    return Card(
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_outlined, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Text('Get an AI review (opt-in)',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This sends the dossier above to the LLM provider you pick, '
              'using the API key you supply. LinkedOut! never sees your '
              'key, never stores it on a server, and only calls the '
              'provider when you press "Get review". The provider will '
              'see whatever you selected above.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<LlmProvider>(
                    initialValue: llm.provider,
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final p in LlmProvider.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) llmCtrl.setProvider(v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: llm.provider.models.contains(llm.model)
                        ? llm.model
                        : llm.provider.defaultModel,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final m in llm.provider.models)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) {
                      if (v != null) llmCtrl.setModel(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (llm.provider.requiresKey)
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'API key',
                  hintText: llm.provider.keyHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  helperText: 'Sent only to ${llm.provider.label}. Never to LinkedOut!.',
                ),
                controller: TextEditingController(text: llm.apiKey)
                  ..selection = TextSelection.collapsed(offset: llm.apiKey.length),
                onChanged: llmCtrl.setApiKey,
              )
            else
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Ollama base URL',
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText: 'Defaults to http://localhost:11434',
                ),
                controller: TextEditingController(text: llm.ollamaBaseUrl),
                onChanged: llmCtrl.setOllamaBaseUrl,
              ),
            const SizedBox(height: 8),
            if (llm.provider.requiresKey)
              Row(
                children: [
                  Checkbox(
                    value: llm.rememberKey,
                    onChanged: (v) => llmCtrl.setRememberKey(v ?? false),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Remember key in this browser (IndexedDB). Clear it '
                      'here any time with the button below.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await llmCtrl.clear();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('LLM settings cleared.')),
                      );
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _reviewing || !_canCall(llm)
                      ? null
                      : () => _runReview(dossier, llm),
                  icon: _reviewing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_reviewing ? 'Reviewing...' : 'Get review'),
                ),
                if (_review != null) ...[
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _review = null;
                      _reviewError = null;
                    }),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Clear review'),
                  ),
                ],
              ],
            ),
            if (_reviewError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 18, color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _reviewError!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_review != null) ...[
              const SizedBox(height: 16),
              _ReviewView(review: _review!),
            ],
          ],
        ),
      ),
    );
  }

  bool _canCall(LlmSettings s) {
    if (s.provider.requiresKey && s.apiKey.trim().isEmpty) return false;
    return true;
  }

  Future<void> _runReview(String dossier, LlmSettings settings) async {
    setState(() {
      _reviewing = true;
      _review = null;
      _reviewError = null;
    });
    try {
      final review = await ProfileReviewer.review(
        settings: settings,
        dossierMarkdown: dossier,
      );
      if (!mounted) return;
      setState(() {
        _review = review;
        _reviewing = false;
      });
    } on LlmError catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewError = e.message;
        _reviewing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewError = 'Unexpected error: $e';
        _reviewing = false;
      });
    }
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({required this.review});
  final ProfileReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (review.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Could not parse structured response. Raw text:',
                style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            SelectableText(review.rawResponse ?? '(empty)'),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (review.overall != null)
          _Block(title: 'Overall', body: Text(review.overall!)),
        if (review.headline != null)
          _Block(
            title: 'Headline',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review.headline!.feedback),
                if (review.headline!.variants.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Suggested variants:',
                      style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  for (final v in review.headline!.variants)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: SelectableText(v)),
                          IconButton(
                            iconSize: 16,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Copy',
                            icon: const Icon(Icons.content_copy),
                            onPressed: () => Clipboard.setData(
                              ClipboardData(text: v),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        if (review.summary != null)
          _Block(
            title: 'Summary',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review.summary!.feedback),
                if (review.summary!.suggestedRewrite != null) ...[
                  const SizedBox(height: 8),
                  Text('Suggested rewrite:',
                      style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  _CopyBlock(text: review.summary!.suggestedRewrite!),
                ],
              ],
            ),
          ),
        if (review.positions.isNotEmpty)
          _Block(
            title: 'Positions',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in review.positions) _PositionBlock(p: p),
              ],
            ),
          ),
        if (review.skillsToAdd.isNotEmpty || review.skillsToRemove.isNotEmpty)
          _Block(
            title: 'Skills',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (review.skillsToAdd.isNotEmpty) ...[
                  Text('Add:', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in review.skillsToAdd) Chip(label: Text(s)),
                    ],
                  ),
                ],
                if (review.skillsToRemove.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Consider removing:',
                      style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in review.skillsToRemove)
                        Chip(
                          label: Text(s),
                          backgroundColor: theme.colorScheme.errorContainer,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        if (review.careerPaths.isNotEmpty)
          _Block(
            title: 'Career directions',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in review.careerPaths)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(c)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (review.redFlags.isNotEmpty)
          _Block(
            title: 'Red flags a recruiter might raise',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in review.redFlags)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚠ '),
                        Expanded(child: Text(r)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.body});
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }
}

class _PositionBlock extends StatelessWidget {
  const _PositionBlock({required this.p});
  final PositionReview p;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Position #${p.index + 1}', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(p.feedback),
          if (p.suggestedRewrite != null) ...[
            const SizedBox(height: 6),
            _CopyBlock(text: p.suggestedRewrite!),
          ],
        ],
      ),
    );
  }
}

class _CopyBlock extends StatelessWidget {
  const _CopyBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SelectableText(text)),
          IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Copy',
            icon: const Icon(Icons.content_copy),
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
          ),
        ],
      ),
    );
  }
}
