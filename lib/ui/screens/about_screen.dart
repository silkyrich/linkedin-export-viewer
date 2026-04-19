import 'package:flutter/material.dart';

import '../../core/linkedin_links.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _repoUrl = 'https://github.com/silkyrich/linkedin-export-viewer';
  static const _siteUrl = 'https://silkyrich.github.io/linkedin-export-viewer/';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('About', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _whatsInTheDump(theme),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your data stays in your browser',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'LinkedIn Export Viewer is a static site. When you upload '
                  'your LinkedIn data-export zip, the file is opened by the '
                  'JavaScript running in this tab and never sent to any '
                  'server. There is no backend. The hosting provider (GitHub '
                  'Pages) only serves the HTML/JS — it does not receive your '
                  'archive.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'To keep things convenient across page refreshes, the raw '
                  'zip bytes are cached in your browser\'s IndexedDB. Use '
                  '"Clear data" in the banner above to wipe that cache at '
                  'any time — or use your browser\'s "clear site data" '
                  'option.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Deep-links to LinkedIn open in a new tab with '
                  'noopener/noreferrer so the destination page cannot reach '
                  'back into this one. LinkedIn will see your normal browser '
                  'activity as soon as you arrive on their site — that is '
                  'unchanged by using this viewer.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How to get your export',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'On LinkedIn: Me → Settings & Privacy → Data Privacy → '
                  'Get a copy of your data. Pick "Want something in '
                  'particular?" or download everything. LinkedIn emails '
                  'you a .zip when it is ready (usually minutes for the '
                  'fast bundle, 24h for the full archive).',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('License', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'MIT License. You can fork, host your own copy, and modify '
                  'it freely. See the LICENSE file in the repo for the full '
                  'text. This project is not affiliated with LinkedIn.',
                ),
                const SizedBox(height: 4),
                const Text(
                  '"LinkedIn" is a trademark of LinkedIn Corporation. Schema '
                  'names and CSV headers used here come from the data export '
                  'LinkedIn provides to its own members.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Built with', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'Flutter web (CanvasKit), Riverpod, go_router, the archive + '
                  'csv packages, idb_shim for IndexedDB caching, and '
                  'two_dimensional_scrollables for big tables. The Flow '
                  'graph uses a plain CustomPainter — no JS charting '
                  'library.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openExternalUrl(_repoUrl),
                icon: const Icon(Icons.code),
                label: const Text('Source on GitHub'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openExternalUrl(_siteUrl),
                icon: const Icon(Icons.public),
                label: const Text('Live site'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _whatsInTheDump(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("What's actually in a LinkedIn export",
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'When you click "Get a copy of your data" in LinkedIn, you get '
              'a zip of around 30 CSV files and a folder of HTML articles. '
              'LinkedIn does not label any of them in the UI. Here is what '
              'each one is, grouped by the tab in this viewer that renders it.',
            ),
            const SizedBox(height: 16),
            for (final cat in _categories) _CategoryBlock(cat: cat),
            const SizedBox(height: 8),
            Text(
              'Size note: the messages file is usually by far the largest. '
              'Heavy networkers can see 50,000+ rows / 5+ MB. Everything in '
              'this viewer is built to cope with that — the Messages list '
              'is virtualized, the Activity heatmap and summary counts are '
              'streamed from a pre-built index, and the Advisor dossier '
              'never includes message bodies (only aggregate counts).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Category {
  const _Category({
    required this.icon,
    required this.label,
    required this.route,
    required this.files,
  });
  final IconData icon;
  final String label;
  final String route;
  final List<(String, String)> files; // (filename, one-line description)
}

const _categories = <_Category>[
  _Category(
    icon: Icons.person_outline,
    label: 'Me',
    route: '/me',
    files: [
      ('Profile.csv', 'Your name, headline, industry, summary, addresses, websites.'),
      ('Profile Summary.csv', 'Your "About" section in isolation.'),
      ('Registration.csv', 'When you signed up, from what IP, and which LinkedIn products you subscribe to.'),
      ('Email Addresses.csv', 'Every email LinkedIn has on file, with primary/confirmed flags.'),
      ('PhoneNumbers.csv', 'Every phone number on file.'),
      ('Whatsapp Phone Numbers.csv', 'Any number linked to WhatsApp.'),
      ('Private_identity_asset.csv', 'Internal identity verification blob — mostly opaque.'),
      ('Languages.csv', 'Languages you\'ve declared + self-rated proficiency.'),
    ],
  ),
  _Category(
    icon: Icons.people_outline,
    label: 'Network',
    route: '/network',
    files: [
      ('Connections.csv', 'Every person you\'re connected to, with the date you connected and their employer/title at that moment.'),
      ('Invitations.csv', 'Connection requests in both directions, including pending ones you sent years ago and never got a reply on.'),
      ('Recommendations_Given.csv', 'Recommendations you wrote for other people.'),
      ('Recommendations_Received.csv', 'Ones other people wrote for you.'),
      ('Endorsement_Given_Info.csv', 'Every "Ada endorsed Bob for X" you\'ve ever done.'),
      ('Endorsement_Received_Info.csv', 'Every time someone endorsed you for a skill.'),
    ],
  ),
  _Category(
    icon: Icons.chat_bubble_outline,
    label: 'Messages',
    route: '/messages',
    files: [
      ('messages.csv', 'Every DM you\'ve ever sent or received on LinkedIn, with subject, body, date, and participants. Usually the biggest file.'),
      ('guide_messages.csv', 'LinkedIn\'s internal message system for paid InMails / job-seeker prompts. Often empty.'),
      ('learning_role_play_messages.csv', 'Messages inside LinkedIn Learning role-play exercises. Usually empty.'),
    ],
  ),
  _Category(
    icon: Icons.work_outline,
    label: 'Career',
    route: '/career',
    files: [
      ('Positions.csv', 'Your employment history: company, title, dates, description.'),
      ('Jobs/Job Applications.csv', 'Every Easy-Apply job you\'ve ever submitted, including your answers to screening questions.'),
      ('Jobs/Saved Jobs.csv', 'Jobs you bookmarked.'),
      ('Jobs/Job Seeker Preferences.csv', 'What you told LinkedIn about what you\'re open to — salary, locations, remote, companies.'),
      ('Jobs/Job Applicant Saved Answers.csv', 'Answers you saved for reuse across applications.'),
      ('SavedJobAlerts.csv', 'Saved searches that email you new matches.'),
      ('Job Applicant Saved Screening Question Responses.csv', 'More reusable application answers.'),
    ],
  ),
  _Category(
    icon: Icons.school_outlined,
    label: 'Learning',
    route: '/learning',
    files: [
      ('Learning.csv', 'Every LinkedIn Learning course you\'ve opened, with watch dates and completion status.'),
      ('Articles/Articles/*.html', 'Long-form articles you published on LinkedIn, one HTML file each.'),
    ],
  ),
  _Category(
    icon: Icons.workspace_premium_outlined,
    label: 'Skills & Education',
    route: '/skills',
    files: [
      ('Skills.csv', 'The skills on your profile.'),
      ('Education.csv', 'Schools, degrees, dates, activities.'),
      ('Verifications/Verifications.csv', 'Identity-verification records if you went through LinkedIn\'s ID check.'),
    ],
  ),
  _Category(
    icon: Icons.edit_note_outlined,
    label: 'Content',
    route: '/content',
    files: [
      ('Publications.csv', 'Publications you\'ve listed on your profile.'),
      ('Projects.csv', 'Projects you\'ve listed, with dates, description, URL.'),
      ('Rich_Media.csv', 'Every profile image, header image, and rich-media attachment you\'ve uploaded, with timestamps.'),
    ],
  ),
  _Category(
    icon: Icons.bolt_outlined,
    label: 'Activity',
    route: '/activity',
    files: [
      ('Company Follows.csv', 'Every company page you follow and when you started following.'),
      ('Events.csv', 'LinkedIn events you marked as attending or interested in.'),
    ],
  ),
  _Category(
    icon: Icons.manage_accounts_outlined,
    label: 'Account',
    route: '/account',
    files: [
      ('Receipts_v2.csv', 'Premium / Recruiter / Learning subscription receipts.'),
      ('Ad_Targeting.csv', 'The interest, demographic, company and skill segments LinkedIn uses to target ads at you. Revealingly detailed. Contains several deliberately-duplicated column names (Company Names ×3, Job Titles ×3).'),
    ],
  ),
];

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({required this.cat});
  final _Category cat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cat.icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(cat.label, style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Text(
                '(tab ${cat.route})',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final f in cat.files)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 24),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodySmall,
                  children: [
                    TextSpan(
                      text: '${f.$1} — ',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: f.$2,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
