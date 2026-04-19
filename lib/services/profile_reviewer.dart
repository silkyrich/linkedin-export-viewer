import 'dart:convert';

import '../state/llm_settings.dart';
import 'llm_client.dart';

/// Structured review of a profile dossier. Every field is nullable so the
/// UI can degrade gracefully if the LLM returns incomplete JSON.
class ProfileReview {
  ProfileReview({
    this.overall,
    this.headline,
    this.summary,
    this.positions = const [],
    this.skillsToAdd = const [],
    this.skillsToRemove = const [],
    this.careerPaths = const [],
    this.redFlags = const [],
    this.rawResponse,
  });

  final String? overall;
  final HeadlineReview? headline;
  final SummaryReview? summary;
  final List<PositionReview> positions;
  final List<String> skillsToAdd;
  final List<String> skillsToRemove;
  final List<String> careerPaths;
  final List<String> redFlags;

  /// Raw text (useful when parsing fails).
  final String? rawResponse;

  bool get isEmpty =>
      overall == null &&
      headline == null &&
      summary == null &&
      positions.isEmpty &&
      skillsToAdd.isEmpty &&
      skillsToRemove.isEmpty &&
      careerPaths.isEmpty &&
      redFlags.isEmpty;
}

class HeadlineReview {
  HeadlineReview({required this.feedback, required this.variants});
  final String feedback;
  final List<String> variants;
}

class SummaryReview {
  SummaryReview({required this.feedback, required this.suggestedRewrite});
  final String feedback;
  final String? suggestedRewrite;
}

class PositionReview {
  PositionReview({
    required this.index,
    required this.feedback,
    this.suggestedRewrite,
  });
  final int index;
  final String feedback;
  final String? suggestedRewrite;
}

/// Prompts the configured LLM to return a structured career review of the
/// supplied dossier and parses the response into a [ProfileReview].
class ProfileReviewer {
  static const _system = '''
You are an experienced career coach and LinkedIn profile editor. You read the
profile dossier the user supplies and return a structured review as valid JSON
matching the schema below. Be specific and reference the dossier directly.
Avoid clichés ("passionate about", "driven by", "results-oriented"). Do not
speculate about personal life. Do not hallucinate positions or skills that
aren't in the dossier.

Return ONLY the JSON object. No prose before or after. No markdown fences.

Schema:
{
  "overall": "One paragraph overall read of the profile.",
  "headline": {
    "feedback": "What the current headline communicates and what it misses.",
    "variants": ["headline A", "headline B", "headline C"]
  },
  "summary": {
    "feedback": "What the About/Summary section does well or poorly.",
    "suggested_rewrite": "A full replacement summary, 80-150 words."
  },
  "positions": [
    {
      "index": 0,
      "feedback": "What this role's description communicates.",
      "suggested_rewrite": "A tighter replacement description."
    }
  ],
  "skills_to_add": ["skill 1", "skill 2"],
  "skills_to_remove": ["stale skill 1"],
  "career_paths": ["Direction 1 with one-line rationale", "Direction 2"],
  "red_flags": ["What a recruiter might question on first pass"]
}
''';

  static Future<ProfileReview> review({
    required LlmSettings settings,
    required String dossierMarkdown,
  }) async {
    final raw = await LlmClient.chat(
      settings: settings,
      system: _system,
      user: dossierMarkdown,
      maxTokens: 3000,
    );
    return _parse(raw);
  }

  static ProfileReview _parse(String raw) {
    // Tolerate stray prose or markdown fences — find the first/last curly
    // brace and parse whatever's between them.
    final first = raw.indexOf('{');
    final last = raw.lastIndexOf('}');
    if (first < 0 || last <= first) {
      return ProfileReview(rawResponse: raw);
    }
    final jsonSlice = raw.substring(first, last + 1);
    Map<String, dynamic> m;
    try {
      m = jsonDecode(jsonSlice) as Map<String, dynamic>;
    } catch (_) {
      return ProfileReview(rawResponse: raw);
    }

    HeadlineReview? headline;
    final h = m['headline'];
    if (h is Map) {
      headline = HeadlineReview(
        feedback: (h['feedback'] as String?) ?? '',
        variants:
            ((h['variants'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
    }

    SummaryReview? summary;
    final s = m['summary'];
    if (s is Map) {
      summary = SummaryReview(
        feedback: (s['feedback'] as String?) ?? '',
        suggestedRewrite: s['suggested_rewrite'] as String?,
      );
    }

    final positions = <PositionReview>[];
    final pos = m['positions'];
    if (pos is List) {
      for (final p in pos) {
        if (p is Map) {
          positions.add(PositionReview(
            index: (p['index'] as num?)?.toInt() ?? positions.length,
            feedback: (p['feedback'] as String?) ?? '',
            suggestedRewrite: p['suggested_rewrite'] as String?,
          ));
        }
      }
    }

    List<String> strList(String key) {
      final v = m[key];
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return ProfileReview(
      overall: m['overall'] as String?,
      headline: headline,
      summary: summary,
      positions: positions,
      skillsToAdd: strList('skills_to_add'),
      skillsToRemove: strList('skills_to_remove'),
      careerPaths: strList('career_paths'),
      redFlags: strList('red_flags'),
      rawResponse: raw,
    );
  }
}
