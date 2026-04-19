// Generates a schema-faithful, obviously-fake LinkedIn data export under
// fixtures/sample_export/ and zips it to fixtures/sample_export.zip.
//
// Deterministic: seeded with Random(42). Re-running produces identical bytes.
//
// Fake-data rules:
//   - Names from a pool of historical figures and fictional characters.
//   - Emails at @example.com, phones in the 555-01xx reserved range,
//     fictional companies (Cyberdyne, Initech, Weyland-Yutani, Hooli...).
//   - LinkedIn profile URLs use obviously-fake slugs (.../in/fake-<slug>).
//   - No real person, company, or place should appear.
//
// Run: dart run tool/generate_fixture.dart

import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:csv/csv.dart';

import 'personas.dart' as p;

const _fixturesDir = 'fixtures/sample_export';
const _zipPath = 'fixtures/sample_export.zip';

// Message count scales with a multiplier passed on the CLI; default 20000.
int _targetMessages = 20000;
int _connectionsCount = 2000;
int _endorsementsGivenCount = 1500;
int _endorsementsReceivedCount = 700;

void main(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--messages=')) {
      _targetMessages = int.parse(arg.substring('--messages='.length));
    }
  }

  final rng = Random(42);
  final root = Directory(_fixturesDir);
  if (root.existsSync()) root.deleteSync(recursive: true);
  root.createSync(recursive: true);
  Directory('$_fixturesDir/Jobs').createSync(recursive: true);
  Directory('$_fixturesDir/Verifications').createSync(recursive: true);
  Directory('$_fixturesDir/Articles/Articles').createSync(recursive: true);

  stdout.writeln('Generating synthetic LinkedIn export at $_fixturesDir/...');

  final me = _Me.generate(rng);
  // Crafted personas go at the front of the contact list so they own the
  // top of Connections and feature heavily in the scripted threads and
  // recommendations. Filler synthetic contacts follow.
  final personas = [
    for (final persona in p.personas.where((x) => !x.invitationOnly))
      _Contact(
        firstName: persona.first,
        lastName: persona.last,
        email: '${_slugify(persona.first)}.${_slugify(persona.last)}@example.com',
        company: persona.company,
        position: persona.position,
        slug: persona.slug,
        connectedOn: _parseDateLinkedin(persona.connectedOn),
      ),
  ];
  final fillerCount = _connectionsCount - personas.length;
  final filler = List.generate(
    fillerCount + 50,
    (i) => _Contact.generate(rng, i + personas.length),
  );
  final contacts = [...personas, ...filler];
  final skills = _skillPool.toList()..shuffle(rng);

  // Identity
  _writeProfile(me);
  _writeProfileSummary(me);
  _writeRegistration(me, rng);
  _writeEmailAddresses(me);
  _writePhoneNumbers(me);
  _writeWhatsappPhoneNumbers(me);
  _writePrivateIdentityAsset(me);

  // Network
  _writeConnections(contacts.take(_connectionsCount).toList());
  _writeRecommendationsGiven(contacts, rng);
  _writeRecommendationsReceived(contacts, rng);
  _writeEndorsementsGiven(contacts, skills, rng, _endorsementsGivenCount);
  _writeEndorsementsReceived(contacts, skills, rng, _endorsementsReceivedCount);
  _writeInvitations(contacts, me, rng);

  // Communication
  _writeMessages(contacts, me, rng);
  _writeEmptyMessages('$_fixturesDir/guide_messages.csv');
  _writeEmptyMessages('$_fixturesDir/learning_role_play_messages.csv');

  // Career
  _writePositions(rng);
  _writeJobApplications(rng);
  _writeSavedJobs(rng);
  _writeJobSeekerPreferences();
  _writeJobApplicantSavedAnswers();
  _writeSavedJobAlerts(rng);
  _writeJobApplicantScreeningResponses();

  // Learning
  _writeLearning(rng);
  _writeArticles();

  // Skills & Education
  _writeEducation();
  _writeSkills(skills);
  _writeLanguages();
  _writeVerifications();

  // Content
  _writePublications();
  _writeProjects(rng);
  _writeRichMedia(rng);

  // Activity
  _writeCompanyFollows(rng);
  _writeEvents(rng);
  _writeReactions(rng);
  _writeShares(rng);
  _writeComments(rng);
  _writeVotes(rng);
  _writeSavedArticles(rng);

  // Account
  _writeReceipts(me, rng);
  _writeAdTargeting();

  _zipFixtures();

  stdout.writeln('Done. Wrote $_fixturesDir/ and $_zipPath');
}

// ---------------------------------------------------------------------------
// Data pools

const _historicalFirst = [
  'Ada', 'Grace', 'Alan', 'Rosalind', 'Katherine', 'Dorothy', 'Mary',
  'Charles', 'Sofia', 'Hedy', 'Claude', 'Dennis', 'Edsger', 'Donald',
  'Marie', 'Nikola', 'Enrico', 'Barbara', 'Rachel', 'Jane', 'Frances',
  'Emmy', 'Maryam', 'Shakuntala', 'Hypatia', 'Srinivasa', 'John',
  'Margaret', 'Radia', 'Evelyn', 'Annie', 'Henrietta', 'Lise',
  'Chien-Shiung', 'Vera', 'Jocelyn', 'Emmy', 'Ada', 'Beatrice',
  'Dorothy', 'Elizabeth',
];

// Note: we intentionally exclude the surnames of the 10 crafted personas
// (Babbage, Somerville, Faraday, Nightingale, De Morgan, Herschel, Whewell,
// Dickens, Shelley, Byron, Lovelace) so a random synthetic contact can't
// collide with them. Before this, "Marie Shelley" would show up in
// Most-messaged and look like our crafted Mary Shelley.
const _historicalLast = [
  'Hopper', 'Turing', 'Franklin', 'Johnson', 'Vaughan',
  'Jackson', 'Kovalevskaya', 'Lamarr', 'Shannon', 'Ritchie',
  'Dijkstra', 'Knuth', 'Curie', 'Tesla', 'Fermi', 'Liskov', 'Carson',
  'Goodall', 'Perkins', 'Noether', 'Mirzakhani', 'Devi', 'of Alexandria',
  'Ramanujan', 'von Neumann', 'Hamilton', 'Perlman', 'Boyd', 'Cannon',
  'Leavitt', 'Meitner', 'Wu', 'Rubin', 'Bell Burnell',
  'Blackwell', 'Blackburn',
];

const _fictionalFirst = [
  'Hermione', 'Atticus', 'Elizabeth', 'Sherlock', 'Jean-Luc', 'Leia',
  'Frodo', 'Samwise', 'Arya', 'Tyrion', 'Luna', 'Ron', 'Neville',
  'Padme', 'Ellen', 'Dana', 'Trinity', 'Neo', 'Morpheus', 'Katniss',
  'Peeta', 'Bilbo', 'Aragorn', 'Galadriel', 'Eowyn', 'Faramir',
  'Belle', 'Mulan', 'Moana', 'Elsa', 'Anna', 'Simba',
];

const _fictionalLast = [
  'Granger', 'Finch', 'Bennet', 'Holmes', 'Picard', 'Organa',
  'Baggins', 'Gamgee', 'Stark', 'Lannister', 'Lovegood', 'Weasley',
  'Longbottom', 'Amidala', 'Ripley', 'Scully', 'Anderson', 'Everdeen',
  'Mellark', 'Took', 'son of Arathorn', 'of Lothlorien', 'of Rohan',
  'of Ithilien', 'Reyes', 'Fa', 'of Motunui', 'of Arendelle',
];

const _madeUpFirst = [
  'Quill', 'Rhonda', 'Zara', 'Caspian', 'Nova', 'Kael', 'Seren',
  'Orin', 'Briar', 'Wren', 'Tessa', 'Linnea', 'Milo', 'Juno',
  'Ezra', 'Sable', 'Thistle', 'Fable',
];

const _madeUpLast = [
  'Fenwick', 'Quibble', 'Moonglow', 'Hollow', 'Pembrook', 'Ashford',
  'Winterbourne', 'Bramble', 'Thornwood', 'Ravensong', 'Harbinger',
  'Summerfield', 'Brookworth',
  // 'Nightingale' was here but collided with our crafted persona.
];

List<String> get _firstNames => [..._historicalFirst, ..._fictionalFirst, ..._madeUpFirst];
List<String> get _lastNames => [..._historicalLast, ..._fictionalLast, ..._madeUpLast];

const _companies = [
  'Royal Society', 'Royal Institution', 'Royal Astronomical Society',
  'Royal Geographical Society', 'British Association for the Advancement of Science',
  'Linnean Society', 'Geological Society of London',
  'Trinity College, Cambridge', 'King\'s College London',
  'University College London', 'University of Edinburgh',
  'Royal Greenwich Observatory', 'Admiralty',
  'Her Majesty\'s Treasury', 'General Post Office',
  'Analytical Engines (stealth)', 'Difference Engine Company',
  'Household Words', 'Punch Magazine',
  'Mechanics\' Institute', 'Board of Longitude',
  'Great Western Railway', 'London and Birmingham Railway',
  'East India Company', 'British Museum',
];

// Modern corporate titles draped onto Victorian networking — the
// anachronism is the joke.
const _titles = [
  'Fellow', 'Senior Fellow', 'Principal Investigator',
  'Head of Correspondence', 'Master of the Mint',
  'Director of Natural Philosophy', 'Chief Experimental Officer',
  'Senior Lecturer', 'Lecturer (Tenure Track)', 'Reader',
  'Editor', 'Senior Editor', 'Publisher',
  'Astronomer Royal, Deputy', 'Curator',
  'Civil Engineer', 'Surveyor', 'Mill Owner',
  'Partner', 'Founding Partner',
  'Secretary, Royal Society', 'Honorary Secretary',
];

const _skillPool = [
  'Dart', 'Flutter', 'TypeScript', 'JavaScript', 'Python', 'Go', 'Rust',
  'Java', 'Kotlin', 'Swift', 'C++', 'SQL', 'PostgreSQL', 'MySQL',
  'MongoDB', 'Redis', 'GraphQL', 'REST APIs', 'gRPC', 'Kafka',
  'RabbitMQ', 'Docker', 'Kubernetes', 'Terraform', 'AWS', 'GCP',
  'Azure', 'Linux', 'Git', 'CI/CD', 'TDD', 'Code Review', 'Agile',
  'Microservices', 'Distributed Systems', 'System Design',
  'Machine Learning', 'Data Engineering', 'Observability',
  'Security Engineering', 'Product Strategy', 'People Management',
  'Mentoring', 'Technical Writing', 'Public Speaking', 'Recruiting',
  'Hiring', 'Incident Response', 'On-Call', 'Architecture',
  'Performance Tuning', 'Scalability', 'Accessibility', 'UX Design',
  'Mobile Development', 'Cross-Platform Development', 'Web Performance',
  'Type Theory', 'Functional Programming', 'Reactive Programming',
];

// Dead-pan corporate LinkedIn register translated into the mid-Victorian
// correspondence idiom. Each line should read like a LinkedIn DM that
// happens to be written with a quill.
const _messageOpenings = [
  'Following up on our conversation at the Royal Institution —',
  'Hope your week at the Observatory went well.',
  'Thanks for the kind reception at Lady Byron\'s salon.',
  'Circling back regarding the society meeting on Tuesday.',
  'Re: the attached monograph —',
  'Quick question on the Bernoulli sequence —',
  'Saw your paper in the Transactions.',
  'Loved your lecture at the Mechanics\' Institute.',
  'Would you be open to a brief correspondence on',
  'Re: the Committee\'s resolution —',
];

const _messageBodies = [
  'The Society is convening a special panel next quarter; your background would fit well.',
  'I am working on something related and would value a comparison of notes.',
  'Are you free for a brief meeting at the Institution this week?',
  'No urgency — flagging in case it is relevant to your current work.',
  'Happy to forward a letter of introduction if it would help.',
  'A Fellowship is opening that may be of interest.',
  'Thank you again for the thoughtful feedback on the draft.',
  'Sharing the enclosed in case it is useful to your enquiries.',
  'Please let me know a day and hour that would suit.',
  'I look forward to your response at your earliest convenience.',
];

// ---------------------------------------------------------------------------
// Entity generators

class _Me {
  _Me({
    required this.firstName,
    required this.lastName,
    required this.headline,
    required this.summary,
    required this.industry,
    required this.zip,
    required this.geo,
    required this.email,
    required this.phone,
    required this.registeredAt,
    required this.registrationIp,
    required this.slug,
  });

  final String firstName;
  final String lastName;
  final String headline;
  final String summary;
  final String industry;
  final String zip;
  final String geo;
  final String email;
  final String phone;
  final DateTime registeredAt;
  final String registrationIp;
  final String slug;

  String get profileUrl => 'https://www.linkedin.com/in/$slug';

  static _Me generate(Random rng) {
    return _Me(
      firstName: p.meFirstName,
      lastName: p.meLastName,
      headline: p.meHeadline,
      summary: p.meSummary,
      industry: 'Mathematics and Computation',
      zip: 'EX1 2MP',
      geo: 'London, England, United Kingdom',
      email: 'ada.example@example.com',
      phone: '+44 20 5550 0100',
      registeredAt: DateTime.utc(1833, 6, 5, 14, 0, 0),
      registrationIp: '203.0.113.42',
      slug: p.meSlug,
    );
  }
}

class _Contact {
  _Contact({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.company,
    required this.position,
    required this.slug,
    required this.connectedOn,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String company;
  final String position;
  final String slug;
  final DateTime connectedOn;

  String get profileUrl => 'https://www.linkedin.com/in/$slug';
  String get fullName => '$firstName $lastName';

  static _Contact generate(Random rng, int index) {
    final first = _firstNames[rng.nextInt(_firstNames.length)];
    final last = _lastNames[rng.nextInt(_lastNames.length)];
    final slug = 'fake-${_slugify(first)}-${_slugify(last)}-$index';
    final company = _companies[rng.nextInt(_companies.length)];
    final title = _titles[rng.nextInt(_titles.length)];
    final year = 1833 + rng.nextInt(20); // 1833..1852 — contemporary with Ada
    final month = 1 + rng.nextInt(12);
    final day = 1 + rng.nextInt(28);
    return _Contact(
      firstName: first,
      lastName: last,
      email: '${_slugify(first)}.${_slugify(last)}.$index@example.com',
      company: company,
      position: title,
      slug: slug,
      connectedOn: DateTime.utc(year, month, day),
    );
  }
}

// ---------------------------------------------------------------------------
// CSV helpers

const _csv = ListToCsvConverter(eol: '\n');

void _writeCsv(String path, List<String> headers, List<List<Object?>> rows) {
  final all = <List<Object?>>[headers, ...rows];
  File(path).writeAsStringSync('${_csv.convert(all)}\n');
}

String _slugify(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp('^-|-\$'), '');

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _linkedinDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

/// Parse the LinkedIn `dd MMM yyyy` date format back into a DateTime.
DateTime _parseDateLinkedin(String s) {
  const months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };
  final parts = s.trim().split(' ');
  if (parts.length != 3) return DateTime.utc(2000);
  final day = int.tryParse(parts[0]) ?? 1;
  final month = months[parts[1]] ?? 1;
  final year = int.tryParse(parts[2]) ?? 2000;
  return DateTime.utc(year, month, day);
}

String _utcTimestamp(DateTime d) =>
    '${_isoDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')} UTC';

/// Parse `YYYY-MM-DD HH:MM` from scripted persona message dates.
DateTime _parseScriptedDate(String s) {
  final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
  return d?.toUtc() ?? DateTime.utc(1840);
}

// ---------------------------------------------------------------------------
// Identity writers

void _writeProfile(_Me me) {
  _writeCsv(
    '$_fixturesDir/Profile.csv',
    [
      'First Name', 'Last Name', 'Maiden Name', 'Address', 'Birth Date',
      'Headline', 'Summary', 'Industry', 'Zip Code', 'Geo Location',
      'Twitter Handles', 'Websites', 'Instant Messengers',
    ],
    [
      [
        me.firstName, me.lastName, '', '221B Baker Street, London',
        '1815-12-10', me.headline, me.summary, me.industry, me.zip, me.geo,
        '[@ada_example]', '[https://example.com/ada]', '',
      ],
    ],
  );
}

void _writeProfileSummary(_Me me) {
  _writeCsv(
    '$_fixturesDir/Profile Summary.csv',
    ['Profile Summary'],
    [[me.summary]],
  );
}

void _writeRegistration(_Me me, Random rng) {
  _writeCsv(
    '$_fixturesDir/Registration.csv',
    ['Registered At', 'Registration Ip', 'Subscription Types'],
    [
      [_utcTimestamp(me.registeredAt), me.registrationIp, 'Core/Free'],
    ],
  );
}

void _writeEmailAddresses(_Me me) {
  _writeCsv(
    '$_fixturesDir/Email Addresses.csv',
    ['Email Address', 'Confirmed', 'Primary', 'Updated On'],
    [
      [me.email, 'Yes', 'Yes', _utcTimestamp(me.registeredAt)],
      ['ada.personal@example.com', 'Yes', 'No', _utcTimestamp(me.registeredAt.add(const Duration(days: 365)))],
    ],
  );
}

void _writePhoneNumbers(_Me me) {
  _writeCsv(
    '$_fixturesDir/PhoneNumbers.csv',
    ['Extension', 'Number', 'Type'],
    [
      ['+44', '20 5550 0100', 'Mobile'],
      ['+44', '20 5550 0101', 'Home'],
      ['+1', '555-01-0123', 'Work'],
      ['+1', '555-01-0124', 'Other'],
    ],
  );
}

void _writeWhatsappPhoneNumbers(_Me me) {
  _writeCsv(
    '$_fixturesDir/Whatsapp Phone Numbers.csv',
    ['Number', 'Extension', 'Is_WhatsApp_Number'],
    [
      ['20 5550 0100', '+44', 'true'],
    ],
  );
}

void _writePrivateIdentityAsset(_Me me) {
  _writeCsv(
    '$_fixturesDir/Private_identity_asset.csv',
    ['Private Identity Asset Name', 'Private Identity Asset Raw Text'],
    [
      [
        'linkedin-identity-verification',
        '{"type":"fake_attestation","issuer":"synthetic","subject":"fake-ada-byron-example","payload":"'
            '${'A' * 512}"}',
      ],
    ],
  );
}

// ---------------------------------------------------------------------------
// Network writers

void _writeConnections(List<_Contact> contacts) {
  final buf = StringBuffer()
    ..writeln('Notes:')
    ..writeln('"When importing your data into a new LinkedIn account, all of '
        'the data in the file will be imported as-is. For more information '
        'see: https://www.example.com/help/linkedin/answer/synthetic. Note '
        'that this file was generated by tool/generate_fixture.dart and '
        'contains no real personal data."')
    ..writeln()
    ..writeln('First Name,Last Name,URL,Email Address,Company,Position,Connected On');
  for (final c in contacts) {
    buf.writeln(_csv.convert([
      [c.firstName, c.lastName, c.profileUrl, c.email, c.company, c.position, _linkedinDate(c.connectedOn)],
    ]));
  }
  File('$_fixturesDir/Connections.csv').writeAsStringSync(buf.toString());
}

void _writeRecommendationsGiven(List<_Contact> contacts, Random rng) {
  final rows = <List<Object?>>[];
  // Scripted recs written by Ada first.
  for (final persona in p.personas) {
    if (persona.recommendationToThem == null) continue;
    rows.add([
      persona.first, persona.last, persona.company, persona.position,
      persona.recommendationToThem,
      _linkedinDate(_parseDateLinkedin(persona.connectedOn.isEmpty ? '01 Jan 1840' : persona.connectedOn)),
      'VISIBLE',
    ]);
  }
  // Filler to pad the count.
  for (var i = 0; i < 20; i++) {
    final c = contacts[rng.nextInt(contacts.length)];
    rows.add([
      c.firstName, c.lastName, c.company, c.position,
      'Worked with ${c.firstName} on a project of mutual interest. '
          'Consistently delivered strong work. Recommended.',
      _linkedinDate(DateTime.utc(1838 + rng.nextInt(14), 1 + rng.nextInt(12), 1 + rng.nextInt(28))),
      'VISIBLE',
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Recommendations_Given.csv',
    ['First Name', 'Last Name', 'Company', 'Job Title', 'Text', 'Creation Date', 'Status'],
    rows,
  );
}

void _writeRecommendationsReceived(List<_Contact> contacts, Random rng) {
  final rows = <List<Object?>>[];
  // Scripted recs written about Ada first.
  for (final persona in p.personas) {
    if (persona.recommendationFromThem == null) continue;
    rows.add([
      persona.first, persona.last, persona.company, persona.position,
      persona.recommendationFromThem,
      _linkedinDate(_parseDateLinkedin(persona.connectedOn.isEmpty ? '01 Jan 1843' : persona.connectedOn)),
      'VISIBLE',
    ]);
  }
  for (var i = 0; i < 24; i++) {
    final c = contacts[rng.nextInt(contacts.length)];
    rows.add([
      c.firstName, c.lastName, c.company, c.position,
      '${c.firstName} is the rare correspondent who actually reads the '
          'attachment before replying. Highly recommended.',
      _linkedinDate(DateTime.utc(1838 + rng.nextInt(14), 1 + rng.nextInt(12), 1 + rng.nextInt(28))),
      'VISIBLE',
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Recommendations_Received.csv',
    ['First Name', 'Last Name', 'Company', 'Job Title', 'Text', 'Creation Date', 'Status'],
    rows,
  );
}

void _writeEndorsementsGiven(List<_Contact> contacts, List<String> skills, Random rng, int count) {
  final rows = <List<Object?>>[];
  // Scripted endorsements Ada gave out.
  for (final persona in p.personas) {
    for (final skill in persona.endorsementsToThem) {
      rows.add([
        _linkedinDate(_parseDateLinkedin(persona.connectedOn.isEmpty ? '01 Feb 1841' : persona.connectedOn)),
        skill,
        persona.first, persona.last, persona.profileUrl, 'ACCEPTED',
      ]);
    }
  }
  for (var i = rows.length; i < count; i++) {
    final c = contacts[rng.nextInt(contacts.length)];
    final skill = skills[rng.nextInt(skills.length)];
    rows.add([
      _linkedinDate(DateTime.utc(1838 + rng.nextInt(14), 1 + rng.nextInt(12), 1 + rng.nextInt(28))),
      skill,
      c.firstName, c.lastName, c.profileUrl, 'ACCEPTED',
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Endorsement_Given_Info.csv',
    [
      'Endorsement Date', 'Skill Name',
      'Endorsee First Name', 'Endorsee Last Name', 'Endorsee Public Url',
      'Endorsement Status',
    ],
    rows,
  );
}

void _writeEndorsementsReceived(List<_Contact> contacts, List<String> skills, Random rng, int count) {
  final rows = <List<Object?>>[];
  // Scripted endorsements Ada received.
  for (final persona in p.personas) {
    for (final skill in persona.endorsementsFromThem) {
      rows.add([
        _linkedinDate(_parseDateLinkedin(persona.connectedOn.isEmpty ? '01 Feb 1841' : persona.connectedOn)),
        skill,
        persona.first, persona.last, persona.profileUrl, 'ACCEPTED',
      ]);
    }
  }
  for (var i = rows.length; i < count; i++) {
    final c = contacts[rng.nextInt(contacts.length)];
    final skill = skills[rng.nextInt(skills.length)];
    rows.add([
      _linkedinDate(DateTime.utc(1838 + rng.nextInt(14), 1 + rng.nextInt(12), 1 + rng.nextInt(28))),
      skill,
      c.firstName, c.lastName, c.profileUrl, 'ACCEPTED',
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Endorsement_Received_Info.csv',
    [
      'Endorsement Date', 'Skill Name',
      'Endorser First Name', 'Endorser Last Name', 'Endorser Public Url',
      'Endorsement Status',
    ],
    rows,
  );
}

void _writeInvitations(List<_Contact> contacts, _Me me, Random rng) {
  final rows = <List<Object?>>[];
  // Scripted pending-forever invitations (Byron, etc.) first.
  for (final persona in p.personas.where((x) => x.invitationOnly)) {
    final outgoing = persona.invitationDirection == 'OUTGOING';
    rows.add([
      outgoing ? '${me.firstName} ${me.lastName}' : persona.fullName,
      outgoing ? persona.fullName : '${me.firstName} ${me.lastName}',
      _utcTimestamp(DateTime.utc(1823, 7, 18, 11, 0)),
      outgoing
          ? 'Father — I understand Mother has reluctantly permitted me to '
              'write. I would very much like to make your acquaintance. '
              'Ada.'
          : '',
      persona.invitationDirection,
      outgoing ? me.profileUrl : persona.profileUrl,
      outgoing ? persona.profileUrl : me.profileUrl,
    ]);
  }
  for (var i = rows.length; i < 162; i++) {
    final c = contacts[rng.nextInt(contacts.length)];
    final outgoing = rng.nextBool();
    final sentAt = _utcTimestamp(DateTime.utc(1833 + rng.nextInt(19), 1 + rng.nextInt(12), 1 + rng.nextInt(28), rng.nextInt(24), rng.nextInt(60), rng.nextInt(60)));
    rows.add([
      outgoing ? '${me.firstName} ${me.lastName}' : c.fullName,
      outgoing ? c.fullName : '${me.firstName} ${me.lastName}',
      sentAt,
      rng.nextBool()
          ? 'We met at the Royal Institution lecture. Would you be open to '
              'connecting?'
          : '',
      outgoing ? 'OUTGOING' : 'INCOMING',
      outgoing ? me.profileUrl : c.profileUrl,
      outgoing ? c.profileUrl : me.profileUrl,
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Invitations.csv',
    ['From', 'To', 'Sent At', 'Message', 'Direction', 'inviterProfileUrl', 'inviteeProfileUrl'],
    rows,
  );
}

// ---------------------------------------------------------------------------
// Messages

void _writeMessages(List<_Contact> contacts, _Me me, Random rng) {
  final rows = <List<Object?>>[];
  var conversationIndex = 0;

  // Scripted threads with personas first — these are the ones users will
  // encounter at the top of the Messages list when they open the demo.
  for (final persona in p.personas) {
    if (persona.thread.isEmpty) continue;
    conversationIndex++;
    final convId = 'conv-${conversationIndex.toString().padLeft(6, '0')}';
    for (final sm in persona.thread) {
      final fromName = sm.fromAda ? '${me.firstName} ${me.lastName}' : persona.fullName;
      final fromUrl = sm.fromAda ? me.profileUrl : persona.profileUrl;
      final toName = sm.fromAda ? persona.fullName : '${me.firstName} ${me.lastName}';
      final toUrl = sm.fromAda ? persona.profileUrl : me.profileUrl;
      rows.add([
        convId,
        persona.threadTitle ?? '',
        fromName, fromUrl,
        toName, toUrl,
        _utcTimestamp(_parseScriptedDate(sm.date)),
        sm.subject,
        sm.content,
        'INBOX',
        '',
        sm.isDraft ? 'true' : 'false',
      ]);
    }
  }

  // Filler conversations with random contacts for scale.
  //
  // Weight the random participant picker heavily toward the 10 crafted
  // personas (Babbage, Somerville, Faraday, …) so they dominate the
  // Most-Messaged charts and are easy to find in the Messages list.
  // Without this, the 2,000 random filler contacts each get ~10 messages
  // and the personas get only their 3–5 scripted ones, so the demo
  // appears to be "you, messaging strangers" instead of showcasing
  // the hand-written cast.
  final personaContacts =
      contacts.take(p.personas.where((x) => !x.invitationOnly).length).toList();
  _Contact pickWeighted() {
    // 75% of the time pick a persona; 25% random filler.
    if (personaContacts.isNotEmpty && rng.nextInt(100) < 75) {
      return personaContacts[rng.nextInt(personaContacts.length)];
    }
    return contacts[rng.nextInt(contacts.length)];
  }

  while (rows.length < _targetMessages) {
    conversationIndex++;
    final participantCount = rng.nextInt(100) < 85 ? 1 : (2 + rng.nextInt(3)); // mostly 1:1, some group
    final participants = List.generate(
      participantCount,
      (_) => pickWeighted(),
    );
    // Length distribution: power law, heavy right tail
    final lengthRoll = rng.nextDouble();
    final convoLen = lengthRoll < 0.4
        ? 1 + rng.nextInt(5)
        : lengthRoll < 0.8
            ? 5 + rng.nextInt(30)
            : 30 + rng.nextInt(400);
    final conversationId = 'conv-${conversationIndex.toString().padLeft(6, '0')}';
    final title = participantCount == 1
        ? ''
        : participants.map((p) => p.fullName).join(', ');
    var cursor = DateTime.utc(1833 + rng.nextInt(19), 1 + rng.nextInt(12), 1 + rng.nextInt(28), rng.nextInt(24), rng.nextInt(60));
    for (var i = 0; i < convoLen && rows.length < _targetMessages; i++) {
      final fromMe = rng.nextBool();
      final author = fromMe ? null : participants[rng.nextInt(participants.length)];
      final recipients = participants.map((p) => p.fullName).join(', ');
      final recipientUrls = participants.map((p) => p.profileUrl).join(' ');
      final isDraft = !fromMe ? false : rng.nextInt(200) == 0;
      cursor = cursor.add(Duration(minutes: rng.nextInt(60 * 24 * 3) + 1));
      rows.add([
        conversationId,
        title,
        fromMe ? '${me.firstName} ${me.lastName}' : author!.fullName,
        fromMe ? me.profileUrl : author!.profileUrl,
        fromMe ? recipients : '${me.firstName} ${me.lastName}',
        fromMe ? recipientUrls : me.profileUrl,
        _utcTimestamp(cursor),
        i == 0 ? 'Re: ${_messageOpenings[rng.nextInt(_messageOpenings.length)]}' : '',
        _composeBody(rng, i == 0),
        'INBOX',
        '',
        isDraft ? 'true' : 'false',
      ]);
    }
  }

  _writeCsv(
    '$_fixturesDir/messages.csv',
    [
      'CONVERSATION ID', 'CONVERSATION TITLE', 'FROM', 'SENDER PROFILE URL',
      'TO', 'RECIPIENT PROFILE URLS', 'DATE', 'SUBJECT', 'CONTENT', 'FOLDER',
      'ATTACHMENTS', 'IS MESSAGE DRAFT',
    ],
    rows,
  );
}

String _composeBody(Random rng, bool isFirst) {
  final opener = isFirst
      ? '${_messageOpenings[rng.nextInt(_messageOpenings.length)]} '
      : '';
  final lines = 1 + rng.nextInt(4);
  final body = List.generate(lines, (_) => _messageBodies[rng.nextInt(_messageBodies.length)]).join('\n');
  return '$opener$body';
}

void _writeEmptyMessages(String path) {
  const headers = 'CONVERSATION ID,CONVERSATION TITLE,FROM,SENDER PROFILE URL,TO,RECIPIENT PROFILE URLS,DATE,SUBJECT,CONTENT,FOLDER\n';
  File(path).writeAsStringSync(headers);
}

// ---------------------------------------------------------------------------
// Career writers

void _writePositions(Random rng) {
  final rows = <List<Object?>>[];
  final order = [
    ('Cyberdyne Systems', 'Staff Engineer', 'Developer tooling + platform. Shipped the fake SkyNet SDK.'),
    ('Hooli', 'Senior Software Engineer', 'Worked on the middle-out compression platform.'),
    ('Initech', 'Software Engineer', 'TPS report pipelines and audit tooling.'),
    ('Paper Street Soap Co.', 'Founding Engineer', 'Bootstrapped inventory + commerce stack.'),
    ('Wayne Enterprises', 'Principal Engineer', 'Applied R&D division.'),
    ('Stark Industries', 'Developer Advocate', 'JARVIS ecosystem.'),
    ('Planet Express', 'Software Engineer', 'Intergalactic logistics.'),
    ('Pied Piper', 'Senior Software Engineer', 'Distributed storage.'),
    ('Sterling Cooper', 'Frontend Engineer', 'Creative account portal.'),
    ('Greendale Community College', 'Teaching Assistant', 'Part-time during undergrad.'),
    ('Monsters Inc', 'Intern', 'Summer internship.'),
  ];
  var year = 2024;
  for (final p in order) {
    final end = DateTime.utc(year, 1 + rng.nextInt(12), 1);
    final start = DateTime.utc(year - 2 - rng.nextInt(2), 1 + rng.nextInt(12), 1);
    rows.add([
      p.$1, p.$2, p.$3, 'London, United Kingdom',
      _linkedinDate(start), _linkedinDate(end),
    ]);
    year = start.year;
  }
  _writeCsv(
    '$_fixturesDir/Positions.csv',
    ['Company Name', 'Title', 'Description', 'Location', 'Started On', 'Finished On'],
    rows,
  );
}

void _writeJobApplications(Random rng) {
  final rows = <List<Object?>>[];
  for (var i = 0; i < 25; i++) {
    final company = _companies[rng.nextInt(_companies.length)];
    final title = _titles[rng.nextInt(_titles.length)];
    rows.add([
      _linkedinDate(DateTime.utc(2023 + rng.nextInt(3), 1 + rng.nextInt(12), 1 + rng.nextInt(28))),
      'recruiting@${_slugify(company)}.example',
      '+1 555-01-${rng.nextInt(100).toString().padLeft(2, '0')}0',
      company,
      title,
      'https://example.com/jobs/${_slugify(company)}/${_slugify(title)}-$i',
      'Ada-Byron-Example-Resume-v${1 + rng.nextInt(4)}.pdf',
      'Q: Are you authorized to work? A: Yes. | Q: Salary expectation? A: Competitive.',
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Jobs/Job Applications.csv',
    ['Application Date', 'Contact Email', 'Contact Phone Number', 'Company Name', 'Job Title', 'Job Url', 'Resume Name', 'Question And Answers'],
    rows,
  );
}

void _writeSavedJobs(Random rng) {
  final rows = <List<Object?>>[];
  for (var i = 0; i < 8; i++) {
    final company = _companies[rng.nextInt(_companies.length)];
    final title = _titles[rng.nextInt(_titles.length)];
    rows.add([
      _linkedinDate(DateTime.utc(2024 + rng.nextInt(2), 1 + rng.nextInt(12), 1 + rng.nextInt(28))),
      'https://example.com/jobs/${_slugify(company)}/${_slugify(title)}-saved-$i',
      title,
      company,
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Jobs/Saved Jobs.csv',
    ['Saved Date', 'Job Url', 'Job Title', 'Company Name'],
    rows,
  );
}

void _writeJobSeekerPreferences() {
  _writeCsv(
    '$_fixturesDir/Jobs/Job Seeker Preferences.csv',
    [
      'Locations', 'Industries', 'Company Employee Count', 'Preferred Job Types',
      'Job Titles', 'Open To Recruiters', 'Dream Companies',
      'Profile Shared With Job Poster', 'Job Title For Searching Fast Growing Companies',
      'Introduction Statement', 'Phone Number', 'Job Seeker Activity Level',
      'Preferred Start Time Range', 'Commute Preference Starting Address',
      'Commute Preference Starting Time', 'Mode Of Transportation',
      'Maximum Commute Duration', 'Open Candidate Visibility', 'Job Seeking Urgency Level',
    ],
    [
      [
        'London, United Kingdom|Remote',
        'Computer Software|Internet',
        '51-10000',
        'Full-time',
        'Staff Engineer|Principal Engineer',
        'true',
        'Pied Piper|Stark Industries',
        'true',
        'Staff Engineer',
        'Synthetic profile seeking fictional roles at made-up companies.',
        '+44 20 5550 0100',
        'Active',
        'Immediately',
        '221B Baker Street, London',
        '09:00',
        'Public Transport',
        '45',
        'Recruiters only',
        'Medium',
      ],
    ],
  );
}

void _writeJobApplicantSavedAnswers() {
  _writeCsv(
    '$_fixturesDir/Jobs/Job Applicant Saved Answers.csv',
    ['Question', 'Answer'],
    [
      ['Why do you want to work here?', 'I admire the team and the mission.'],
    ],
  );
}

void _writeSavedJobAlerts(Random rng) {
  final rows = <List<Object?>>[];
  for (var i = 0; i < 5; i++) {
    rows.add([
      'keywords=staff engineer&location=London&remote=true',
      '{"keywords":"staff engineer","location":"London","remote":true}',
      'alert-${rng.nextInt(9999).toString().padLeft(4, '0')}',
    ]);
  }
  _writeCsv(
    '$_fixturesDir/SavedJobAlerts.csv',
    ['ALERT_PARAMETERS', 'QUERY_CONTEXT', 'SAVED_SEARCH_ID'],
    rows,
  );
}

void _writeJobApplicantScreeningResponses() {
  _writeCsv(
    '$_fixturesDir/Job Applicant Saved Screening Question Responses.csv',
    ['Question', 'Answer'],
    [
      ['Are you legally authorized to work in the UK?', 'Yes'],
      ['Do you require visa sponsorship now or in the future?', 'No'],
      ['How many years of experience do you have?', '10+'],
      ['What is your desired salary range?', 'Competitive'],
      ['When can you start?', 'Two weeks notice'],
      ['Are you willing to relocate?', 'No'],
      ['Preferred work arrangement?', 'Remote or hybrid'],
    ],
  );
}

// ---------------------------------------------------------------------------
// Learning + Articles

void _writeLearning(Random rng) {
  final rows = <List<Object?>>[];
  const courses = [
    'Distributed Systems Foundations',
    'Advanced Flutter Performance',
    'Rust for JavaScript Developers',
    'Kubernetes in Depth',
    'Machine Learning for Engineers',
    'PostgreSQL Internals',
    'System Design Interview Prep',
    'Kafka Streams Essentials',
    'gRPC and Protocol Buffers',
    'Observability with OpenTelemetry',
  ];
  for (var i = 0; i < 165; i++) {
    final title = courses[i % courses.length];
    final watched = DateTime.utc(2021 + rng.nextInt(5), 1 + rng.nextInt(12), 1 + rng.nextInt(28));
    final completed = rng.nextBool() ? watched.add(Duration(days: rng.nextInt(30))) : null;
    rows.add([
      '$title (${i + 1})',
      'Synthetic course description covering core concepts of $title.',
      rng.nextBool() ? 'VIDEO' : 'LEARNING_PATH',
      _linkedinDate(watched),
      completed != null ? _linkedinDate(completed) : '',
      rng.nextBool() ? 'true' : 'false',
      '',
      '',
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Learning.csv',
    [
      'Content Title', 'Content Description', 'Content Type',
      'Content Last Watched Date (if viewed)', 'Content Completed At (if completed)',
      'Content Saved', 'Notes taken on videos (if taken)', '',
    ],
    rows,
  );
}

void _writeArticles() {
  const articles = [
    ('2018-07-15_on-shipping-small.html', 'On Shipping Small', 'Most features are too big. Ship the smallest coherent slice.'),
    ('2020-03-02_the-cost-of-good-abstractions.html', 'The Cost of Good Abstractions', 'Every abstraction buys flexibility and charges complexity.'),
    ('2022-11-09_async-rust-a-year-in.html', 'Async Rust, A Year In', 'Notes from running async Rust in production for 12 months.'),
    ('2024-05-18_flutter-web-renderer-tradeoffs.html', 'Flutter Web Renderer Tradeoffs', 'HTML vs CanvasKit in 2024.'),
    ('2026-02-01_browser-first-apps.html', 'Browser-First Apps', 'Why we should build more tools that never leave the tab.'),
  ];
  for (final a in articles) {
    final html = '''<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>${a.$2}</title>
<style>body{font-family:system-ui,sans-serif;max-width:640px;margin:2rem auto;padding:0 1rem;line-height:1.6;}h1{margin-bottom:0.2em;}small{color:#666;}</style>
</head><body>
<h1>${a.$2}</h1>
<small>Synthetic article generated for linkedin-export-viewer fixtures.</small>
<p>${a.$3}</p>
<p>This is placeholder body text. A real article would go here. The fixture generator only stubs out the structure so the Articles viewer has something to render.</p>
<p>— Ada Byron-Example</p>
</body></html>''';
    File('$_fixturesDir/Articles/Articles/${a.$1}').writeAsStringSync(html);
  }
}

// ---------------------------------------------------------------------------
// Skills & Education

void _writeEducation() {
  _writeCsv(
    '$_fixturesDir/Education.csv',
    ['School Name', 'Start Date', 'End Date', 'Notes', 'Degree Name', 'Activities'],
    [
      ['Hogwarts School of Witchcraft and Wizardry', 'Sep 2008', 'Jun 2012', '', 'BSc, Enchanted Computing', 'Quidditch, Charms Club'],
      ['Starfleet Academy', 'Sep 2012', 'Jun 2014', 'Exchange year', 'MSc, Distributed Systems', 'Warp Field Society'],
    ],
  );
}

void _writeSkills(List<String> skills) {
  _writeCsv(
    '$_fixturesDir/Skills.csv',
    ['Name'],
    skills.take(60).map((s) => [s]).toList(),
  );
}

void _writeLanguages() {
  _writeCsv(
    '$_fixturesDir/Languages.csv',
    ['Name', 'Proficiency'],
    [['English', 'Native or bilingual proficiency']],
  );
}

void _writeVerifications() {
  _writeCsv(
    '$_fixturesDir/Verifications/Verifications.csv',
    [
      'First name', 'Middle name', 'Last name', 'Verification type',
      'Organization name', 'Email address', 'Country', 'State', 'City',
      'Year of birth', 'Issuing authority', 'Document type',
      'Verification service provider', 'Verified date', 'Expiry date',
    ],
    [
      [
        'Ada', '', 'Byron-Example', 'Identity',
        'Cyberdyne Systems', 'ada.example@example.com', 'United Kingdom',
        'England', 'London', '1985', 'Synthetic Passport Office', 'Passport',
        'Fake Verify Ltd', _linkedinDate(DateTime.utc(2024, 6, 12)),
        _linkedinDate(DateTime.utc(2029, 6, 12)),
      ],
    ],
  );
}

// ---------------------------------------------------------------------------
// Content writers

void _writePublications() {
  _writeCsv(
    '$_fixturesDir/Publications.csv',
    ['Name', 'Published On', 'Description', 'Publisher', 'Url'],
    [
      ['The Shape of Developer Tools in 2026', _linkedinDate(DateTime.utc(2026, 1, 14)), 'Essay on the tooling landscape.', 'Example Press', 'https://example.com/shape-2026'],
      ['On Browser-First Software', _linkedinDate(DateTime.utc(2025, 8, 3)), 'Why we should run more things in the tab.', 'Synthetic Quarterly', 'https://example.com/browser-first'],
    ],
  );
}

void _writeProjects(Random rng) {
  final rows = <List<Object?>>[];
  const names = [
    'OpenTelemetry for Flutter', 'fake-auth service', 'Distributed lock demo',
    'Offline-first notes app', 'Synthetic fixture generator', 'dart-csv benchmarks',
    'Static site starter', 'Kafka playground', 'GraphQL schema linter',
    'IndexedDB ORM experiment', 'Worker-based CSV parser', 'Canvas-based graph engine',
    'Force-directed layout sim', 'ResponsiveShell widget', 'article-iframe sandbox',
    'go_router hash-strategy demo',
  ];
  for (final n in names) {
    final start = DateTime.utc(2019 + rng.nextInt(6), 1 + rng.nextInt(12), 1 + rng.nextInt(28));
    final end = start.add(Duration(days: 30 + rng.nextInt(365)));
    rows.add([
      n, 'Synthetic project: $n.', 'https://example.com/projects/${_slugify(n)}',
      _linkedinDate(start), _linkedinDate(end),
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Projects.csv',
    ['Title', 'Description', 'Url', 'Started On', 'Finished On'],
    rows,
  );
}

void _writeRichMedia(Random rng) {
  final rows = <List<Object?>>[];
  for (var i = 0; i < 179; i++) {
    final t = DateTime.utc(2019 + rng.nextInt(7), 1 + rng.nextInt(12), 1 + rng.nextInt(28), rng.nextInt(24), rng.nextInt(60));
    rows.add([
      _utcTimestamp(t),
      'Profile image upload v${i + 1}',
      'https://example.com/rich-media/synthetic/$i.png',
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Rich_Media.csv',
    ['Date/Time', 'Media Description', 'Media Link'],
    rows,
  );
}

// ---------------------------------------------------------------------------
// Activity writers

void _writeCompanyFollows(Random rng) {
  final rows = <List<Object?>>[];
  for (var i = 0; i < 52; i++) {
    final c = _companies[i % _companies.length];
    rows.add([c, _linkedinDate(DateTime.utc(2019 + rng.nextInt(6), 1 + rng.nextInt(12), 1 + rng.nextInt(28)))]);
  }
  _writeCsv(
    '$_fixturesDir/Company Follows.csv',
    ['Organization', 'Followed On'],
    rows,
  );
}

void _writeEvents(Random rng) {
  const events = [
    'Fictional Flutter Summit 2024',
    'Synthetic Rust Conf 2023',
    'Example.com Dev Day 2025',
    'Pretend GraphQL Summit',
    'Faux Kubernetes Con',
    'Imaginary Dart Meetup',
    'Nonexistent AI Workshop',
    'Placeholder Product Summit',
    'Stand-in Leadership Forum',
  ];
  final rows = <List<Object?>>[];
  for (final e in events) {
    final t = DateTime.utc(2023 + rng.nextInt(3), 1 + rng.nextInt(12), 1 + rng.nextInt(28), 9 + rng.nextInt(8), 0);
    rows.add([
      e,
      _utcTimestamp(t),
      rng.nextBool() ? 'ATTENDING' : 'INTERESTED',
      'https://example.com/events/${_slugify(e)}',
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Events.csv',
    ['Event Name', 'Event Time', 'Status', 'External Url'],
    rows,
  );
}

// ---------------------------------------------------------------------------
// Social activity writers (Complete-archive files)

const _reactionTypes = ['LIKE', 'PRAISE', 'EMPATHY', 'INTEREST', 'APPRECIATION', 'MAYBE'];
const _postTopics = [
  'the new Analytical Engine spec',
  'Bernoulli sequence programming',
  'operational-card notation',
  'hospital mortality statistics',
  'electromagnetic induction',
  'Translator\'s Notes',
  'the symbolic logic debate',
  'Jacquard loom patterns',
  'the state of Cambridge mathematics',
  'astronomy photography',
];

String _fakePostUrl(Random rng, int n) =>
    'https://www.linkedin.com/posts/fake-persona-${rng.nextInt(999)}_activity-${7000000000000000 + n}-AaAa';

void _writeReactions(Random rng) {
  final rows = <List<Object?>>[];
  for (var i = 0; i < 80; i++) {
    final t = DateTime.utc(1840 + rng.nextInt(12), 1 + rng.nextInt(12), 1 + rng.nextInt(28));
    rows.add([
      _utcTimestamp(t),
      _reactionTypes[rng.nextInt(_reactionTypes.length)],
      _fakePostUrl(rng, i),
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Reactions.csv',
    ['Date', 'Type', 'Link'],
    rows,
  );
}

void _writeShares(Random rng) {
  final rows = <List<Object?>>[];
  for (var i = 0; i < 25; i++) {
    final t = DateTime.utc(1840 + rng.nextInt(12), 1 + rng.nextInt(12), 1 + rng.nextInt(28));
    final topic = _postTopics[rng.nextInt(_postTopics.length)];
    rows.add([
      _utcTimestamp(t),
      _fakePostUrl(rng, i),
      rng.nextBool() ? 'PUBLIC' : 'CONNECTIONS',
      'Sharing this piece on $topic — worth reading if you work on similar questions.',
      rng.nextBool()
          ? 'https://example.com/media/share-${_slugify(topic)}.png'
          : '',
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Shares.csv',
    ['Date', 'ShareLink', 'ShareCommentary', 'SharedUrl', 'MediaUrl'],
    rows,
  );
}

void _writeComments(Random rng) {
  final rows = <List<Object?>>[];
  const comments = [
    'Agreed. The carry-forward pattern here saves a full pass.',
    'Could we adapt this approach for nested sequences?',
    'Fair point on the notation — I\'ll revise mine.',
    'Seeing similar results on our end. Happy to compare notes.',
    'Thanks for the careful response. Useful.',
    'Worth flagging: this only holds when the mill doesn\'t overflow.',
    'Reasonable. Different context, same conclusion.',
  ];
  for (var i = 0; i < 60; i++) {
    final t = DateTime.utc(1840 + rng.nextInt(12), 1 + rng.nextInt(12), 1 + rng.nextInt(28), rng.nextInt(24), rng.nextInt(60));
    rows.add([
      _utcTimestamp(t),
      '${_fakePostUrl(rng, i)}/?commentUrn=urn%3Ali%3Acomment%3A(activity%3A$i)',
      comments[rng.nextInt(comments.length)],
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Comments.csv',
    ['Date', 'Link', 'Message'],
    rows,
  );
}

void _writeVotes(Random rng) {
  final rows = <List<Object?>>[];
  const options = ['Option A', 'Option B', 'Option C', 'Option D'];
  for (var i = 0; i < 15; i++) {
    final t = DateTime.utc(1840 + rng.nextInt(12), 1 + rng.nextInt(12), 1 + rng.nextInt(28));
    rows.add([
      _utcTimestamp(t),
      '${_fakePostUrl(rng, i)}-poll',
      options[rng.nextInt(options.length)],
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Votes.csv',
    ['Date', 'Link', 'OptionText'],
    rows,
  );
}

void _writeSavedArticles(Random rng) {
  final rows = <List<Object?>>[];
  const titles = [
    'Designing for computational clarity',
    'Why notation matters more than people think',
    'On the difficulty of stopping a career',
    'An obituary for the Difference Engine',
    'Victorian managers, modern problems',
    'How we run our correspondence stack',
    'Everything I know about carry-forward',
    'Meetings, dispatches, and the value of a short letter',
  ];
  for (var i = 0; i < titles.length; i++) {
    final t = DateTime.utc(1840 + rng.nextInt(12), 1 + rng.nextInt(12), 1 + rng.nextInt(28));
    rows.add([
      _utcTimestamp(t),
      _fakePostUrl(rng, i + 100),
      titles[i],
    ]);
  }
  _writeCsv(
    '$_fixturesDir/saved_articles.csv',
    ['Saved At', 'Link', 'Name'],
    rows,
  );
}

// ---------------------------------------------------------------------------
// Account writers

void _writeReceipts(_Me me, Random rng) {
  final rows = <List<Object?>>[];
  for (var i = 0; i < 10; i++) {
    final t = DateTime.utc(2022 + rng.nextInt(4), 1 + rng.nextInt(12), 1 + rng.nextInt(28), rng.nextInt(24), rng.nextInt(60));
    final subtotal = 29.99;
    const tax = 6.00;
    rows.add([
      me.firstName, me.lastName, 'United Kingdom', me.zip,
      _utcTimestamp(t), 'CARD_VISA', 'INV-${10000 + i}',
      'LinkedIn Premium Career (monthly)',
      tax.toStringAsFixed(2), subtotal.toStringAsFixed(2),
      (subtotal + tax).toStringAsFixed(2), 'GBP',
    ]);
  }
  _writeCsv(
    '$_fixturesDir/Receipts_v2.csv',
    [
      'First Name', 'Last Name', 'Billing Country', 'Postal Code',
      'Transaction Made At', 'Payment Method Type', 'Invoice Number',
      'Description', 'Tax Amount', 'Sub Total', 'Total Amount', 'Currency Code',
    ],
    rows,
  );
}

void _writeAdTargeting() {
  // Duplicate column names match the real LinkedIn export.
  final headers = [
    'Member Age', 'Buyer Groups',
    'Company Names', 'Company Names', 'Company Follower of', 'Company Names',
    'Company Category', 'Company Size', 'Degrees', 'degreeClass',
    'Recent Device OS', 'Member Schools', 'Company Growth Rate',
    'Fields of Study', 'Company Connections', 'Function By Size',
    'Job Functions', 'Member Gender', 'Graduation Year', 'Member Groups',
    'Company Industries', 'Member Interests', 'Interface Locales',
    'interfaceLocale', 'Member Traits', 'High Value Audience Segments',
    'Profile Locations', 'Company Revenue', 'Job Seniorities',
    'Member Skills', 'Standard Audience Segments',
    'Job Titles', 'Job Titles', 'Job Titles', 'Years of Experience',
  ];
  final row = [
    '30-40', 'Software Decision Makers',
    'Cyberdyne Systems|Hooli|Initech', 'Pied Piper|Stark Industries', 'Hooli|Cyberdyne Systems', 'Wayne Enterprises',
    'Technology', '51-200|201-500|501-1000', 'Bachelor|Master', 'MASTER_OF_SCIENCE',
    'macOS|iOS', 'Hogwarts School|Starfleet Academy', 'Hyper Growth',
    'Computer Science|Engineering', '500+', 'Engineering_51-200',
    'Engineering|Information Technology', 'Unspecified', '2012',
    'Distributed Systems Engineers', 'Computer Software|Internet',
    'Open Source|Developer Tools|Observability',
    'en-GB|en-US', 'en_GB', 'Frequent Travelers|Tech Early Adopters',
    'Senior Decision Makers', 'London|Remote', r'$10M-$50M',
    'Senior|Manager|Director',
    'Dart|Flutter|Rust|Kubernetes|PostgreSQL',
    'B2B Tech Buyers',
    'Staff Engineer', 'Principal Engineer', 'Engineering Manager',
    '10-15 years',
  ];
  _writeCsv('$_fixturesDir/Ad_Targeting.csv', headers, [row]);
}

// ---------------------------------------------------------------------------
// Zip bundler

void _zipFixtures() {
  // Fixed epoch so re-runs produce identical bytes. Without this the zip
  // header embeds the current file mtime and every commit is a diff.
  // Value is the DOS-epoch time for 2020-01-01 00:00:00 UTC.
  const fixedDosTime = 0x50210000;
  final archive = Archive();
  final root = Directory(_fixturesDir);
  final entries = root.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in entries) {
    final rel = f.path.substring(_fixturesDir.length + 1);
    final bytes = f.readAsBytesSync();
    archive.addFile(
      ArchiveFile(rel, bytes.length, bytes)..lastModTime = fixedDosTime,
    );
  }
  final encoded = ZipEncoder().encode(archive);
  File(_zipPath).writeAsBytesSync(encoded);
}
