import 'dart:math';

import '../models/archive.dart';
import '../state/flow_index.dart';

/// The kind of advice the user wants — selecting one prepends a
/// matching prompt at the top of the generated dossier.
enum AdvisorPrompt { careerAdvisor, profileTuneUp, jobMatch, headlineRewrite, openEnded }

extension AdvisorPromptText on AdvisorPrompt {
  String get title => switch (this) {
        AdvisorPrompt.careerAdvisor => 'Career advisor',
        AdvisorPrompt.profileTuneUp => 'Profile tune-up',
        AdvisorPrompt.jobMatch => 'Job match',
        AdvisorPrompt.headlineRewrite => 'Headline rewrite',
        AdvisorPrompt.openEnded => 'What does this say about me?',
      };

  String get promptBody => switch (this) {
        AdvisorPrompt.careerAdvisor =>
          'You are an experienced career coach. Read the LinkedIn profile '
              'dossier below and suggest:\n'
              '1. Two or three career directions that fit the profile.\n'
              '2. Gaps or skills to develop to pursue them.\n'
              '3. Red flags a hiring manager would notice, if any.\n\n'
              'Be concrete. Reference specific roles, skills, or companies '
              'from the dossier. Do not speculate on personal life.',
        AdvisorPrompt.profileTuneUp =>
          'You are a LinkedIn profile editor. Using only the dossier below, '
              'suggest specific improvements:\n'
              '1. Rewrite the Headline to be sharper. Offer 3 variants.\n'
              '2. Identify summary/positions that are vague or weak and '
              'propose replacement wording.\n'
              '3. Flag skills that are stale given the positions timeline.\n\n'
              'Keep the voice professional and concise.',
        AdvisorPrompt.jobMatch =>
          'You are a recruiter reading the dossier below. Propose:\n'
              '1. Five job-title searches that best match this profile '
              '(for generic job boards, not LinkedIn-specific).\n'
              '2. Five company types or segments worth targeting.\n'
              '3. Two roles the profile probably does *not* fit, to rule out.',
        AdvisorPrompt.headlineRewrite =>
          'Read the dossier below and write five alternative LinkedIn '
              'headlines. Each should:\n'
              '- Be under 220 characters.\n'
              '- Lead with the clearest value proposition.\n'
              '- Avoid clichés ("passionate about", "driven by", '
              '"results-oriented").',
        AdvisorPrompt.openEnded =>
          'Read the dossier below and tell me, candidly, what it signals '
              'to someone seeing this profile for the first time. What do '
              'they conclude about seniority, specialisation, trajectory, '
              'and cultural fit? Be specific.',
      };
}

class DossierOptions {
  const DossierOptions({
    this.prompt = AdvisorPrompt.careerAdvisor,
    this.anonymizeContacts = true,
    this.includeTopContactSummaries = false,
    this.maxBytes = 50 * 1024,
  });

  final AdvisorPrompt prompt;

  /// Replace contact names with initials (and truncate profile URLs) so
  /// the dossier doesn't hand LinkedIn contact lists to a third-party LLM.
  final bool anonymizeContacts;

  /// If true, include the top-N correspondents section with counts.
  /// Even when on, only aggregates are included — never message bodies.
  final bool includeTopContactSummaries;

  /// Soft cap on dossier size. Sections are trimmed in order of priority
  /// if we're about to blow past this.
  final int maxBytes;
}

class DossierResult {
  DossierResult({required this.markdown, required this.truncated});
  final String markdown;
  final bool truncated;

  int get bytes => markdown.length;
}

/// Build a Markdown dossier suitable for pasting into an LLM.
DossierResult buildDossier(
  LinkedInArchive archive,
  FlowIndex? flow,
  DossierOptions options,
) {
  final out = StringBuffer();

  // Prompt at the top so you can copy→paste without editing.
  out
    ..writeln('# ${options.prompt.title}')
    ..writeln()
    ..writeln(options.prompt.promptBody)
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln('# Profile dossier')
    ..writeln();

  // Profile
  final profile = archive.file('Profile.csv');
  if (profile != null && profile.rows.isNotEmpty) {
    out.writeln('## Profile');
    final row = profile.rows.first;
    for (var i = 0; i < profile.headers.length; i++) {
      final key = profile.headers[i];
      final value = i < row.length ? row[i] : '';
      if (value.trim().isEmpty) continue;
      if (const {'Address', 'Zip Code', 'Birth Date'}.contains(key)) continue;
      out.writeln('- **$key:** $value');
    }
    out.writeln();
  }

  // Summary
  final summary = archive.file('Profile Summary.csv');
  if (summary != null && summary.rows.isNotEmpty && summary.rows.first.isNotEmpty) {
    out
      ..writeln('## Summary')
      ..writeln()
      ..writeln(summary.rows.first.first)
      ..writeln();
  }

  // Positions
  final positions = archive.file('Positions.csv');
  if (positions != null && positions.rows.isNotEmpty) {
    out.writeln('## Positions');
    for (final r in positions.rows) {
      String f(String k) {
        final idx = positions.headers.indexOf(k);
        return (idx == -1 || idx >= r.length) ? '' : r[idx];
      }

      out
        ..writeln(
          '### ${f('Title')} — ${f('Company Name')}'
          '${f('Location').isNotEmpty ? ' (${f('Location')})' : ''}',
        )
        ..writeln(
          '${f('Started On')} — ${f('Finished On').isEmpty ? 'Present' : f('Finished On')}',
        );
      if (f('Description').isNotEmpty) {
        out
          ..writeln()
          ..writeln(f('Description'));
      }
      out.writeln();
    }
  }

  // Education
  final education = archive.file('Education.csv');
  if (education != null && education.rows.isNotEmpty) {
    out.writeln('## Education');
    for (final r in education.rows) {
      String f(String k) {
        final idx = education.headers.indexOf(k);
        return (idx == -1 || idx >= r.length) ? '' : r[idx];
      }

      out.writeln(
        '- **${f('School Name')}** — ${f('Degree Name')} '
        '(${f('Start Date')}–${f('End Date')})',
      );
    }
    out.writeln();
  }

  // Skills
  final skills = archive.file('Skills.csv');
  if (skills != null && skills.rows.isNotEmpty) {
    out
      ..writeln('## Skills')
      ..writeln()
      ..writeln(
        skills.rows
            .map((r) => r.isEmpty ? '' : r.first)
            .where((s) => s.isNotEmpty)
            .join(', '),
      )
      ..writeln();
  }

  // Top endorsements (skill → count received)
  final endReceived = archive.file('Endorsement_Received_Info.csv');
  if (endReceived != null && endReceived.rows.isNotEmpty) {
    final counts = <String, int>{};
    final skillIdx = endReceived.headers.indexOf('Skill Name');
    for (final r in endReceived.rows) {
      if (skillIdx < 0 || skillIdx >= r.length) continue;
      counts[r[skillIdx]] = (counts[r[skillIdx]] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isNotEmpty) {
      out.writeln('## Top endorsements received');
      for (final e in ranked.take(12)) {
        out.writeln('- ${e.key}: ${e.value}');
      }
      out.writeln();
    }
  }

  // Languages
  final languages = archive.file('Languages.csv');
  if (languages != null && languages.rows.isNotEmpty) {
    out.writeln('## Languages');
    for (final r in languages.rows) {
      String f(String k) {
        final idx = languages.headers.indexOf(k);
        return (idx == -1 || idx >= r.length) ? '' : r[idx];
      }
      out.writeln('- ${f('Name')} — ${f('Proficiency')}');
    }
    out.writeln();
  }

  // Published work
  final pubs = archive.file('Publications.csv');
  if (pubs != null && pubs.rows.isNotEmpty) {
    out.writeln('## Publications');
    for (final r in pubs.rows) {
      String f(String k) {
        final idx = pubs.headers.indexOf(k);
        return (idx == -1 || idx >= r.length) ? '' : r[idx];
      }
      out.writeln(
        '- *${f('Name')}* — ${f('Publisher')} (${f('Published On')})',
      );
    }
    out.writeln();
  }

  // Projects (capped)
  final projects = archive.file('Projects.csv');
  if (projects != null && projects.rows.isNotEmpty) {
    out.writeln('## Projects');
    for (final r in projects.rows.take(10)) {
      String f(String k) {
        final idx = projects.headers.indexOf(k);
        return (idx == -1 || idx >= r.length) ? '' : r[idx];
      }
      out
        ..writeln('- **${f('Title')}** (${f('Started On')}–${f('Finished On')})')
        ..writeln('  ${f('Description')}');
    }
    out.writeln();
  }

  // Companies followed (signal about interests)
  final follows = archive.file('Company Follows.csv');
  if (follows != null && follows.rows.isNotEmpty) {
    final orgs = follows.rows
        .map((r) => r.isEmpty ? '' : r.first)
        .where((s) => s.isNotEmpty)
        .take(25)
        .toList();
    out
      ..writeln('## Companies followed')
      ..writeln()
      ..writeln(orgs.join(', '))
      ..writeln();
  }

  // Ad Targeting — what LinkedIn thinks you are
  final adTargeting = archive.file('Ad_Targeting.csv');
  if (adTargeting != null && adTargeting.rows.isNotEmpty) {
    out.writeln('## How LinkedIn classifies me (ad-targeting segments)');
    final headers = adTargeting.headers;
    final row = adTargeting.rows.first;
    // Group consecutive duplicate headers (Company Names x3 etc.).
    String prev = '';
    for (var i = 0; i < headers.length; i++) {
      final key = headers[i];
      final v = (i < row.length ? row[i] : '').trim();
      if (v.isEmpty) continue;
      if (prev == key) {
        out.write(' · $v');
        continue;
      }
      if (prev.isNotEmpty) out.writeln();
      out.write('- **$key:** $v');
      prev = key;
    }
    out
      ..writeln()
      ..writeln();
  }

  // Activity stats
  if (flow != null && !flow.isEmpty) {
    final years = (flow.maxDate.difference(flow.minDate).inDays / 365).round();
    out
      ..writeln('## Activity stats')
      ..writeln('- Messages exchanged: ${flow.events.length}')
      ..writeln('- Unique contacts messaged: ${flow.contacts.length}')
      ..writeln('- Active range: ${_year(flow.minDate)} – ${_year(flow.maxDate)} ($years years)')
      ..writeln();
  }

  // Optional: top correspondents.
  if (options.includeTopContactSummaries && flow != null && flow.contacts.isNotEmpty) {
    final top = flow.contacts.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    out.writeln('## Top correspondents');
    for (final c in top.take(10)) {
      final name = options.anonymizeContacts ? _initials(c.name) : c.name;
      out.writeln('- $name — ${c.totalOutgoing} sent, ${c.totalIncoming} received');
    }
    out.writeln();
  }

  // Truncate to budget — trim from the end to preserve the highest-value
  // sections (prompt, profile, positions).
  final text = out.toString();
  if (text.length <= options.maxBytes) {
    return DossierResult(markdown: text, truncated: false);
  }
  // Find the last section boundary before the budget to avoid truncating
  // mid-paragraph.
  final truncated = text.substring(0, options.maxBytes);
  final lastBoundary = truncated.lastIndexOf('\n## ');
  final safe = lastBoundary > 0 ? truncated.substring(0, lastBoundary) : truncated;
  return DossierResult(
    markdown:
        '$safe\n\n*Dossier truncated to ${options.maxBytes ~/ 1024} KB.*\n',
    truncated: true,
  );
}

String _year(DateTime d) => d.year.toString();

String _initials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '—';
  if (parts.length == 1) return parts.first.substring(0, min(parts.first.length, 2)).toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
