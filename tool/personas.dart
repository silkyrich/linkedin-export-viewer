// Hand-crafted "Victorian polymath on LinkedIn" cast for the demo fixture.
//
// The humour here is deadpan: every profile is written in the flat,
// professional register of a modern LinkedIn page, which is where the comedy
// comes from. Nothing winks at the reader. Everything is earnest.
//
// All content in this file is fiction. Real historical names are used
// because the project's entire demo conceit is "famous dead people using
// LinkedIn" — the tone is affectionate, nothing here imputes private fact
// to the actual people. Consider this a costume-drama pastiche.

/// One crafted LinkedIn contact, plus how Ada and they interact.
class Persona {
  const Persona({
    required this.first,
    required this.last,
    required this.slug,
    required this.company,
    required this.position,
    required this.headline,
    required this.summary,
    required this.connectedOn,
    required this.endorsementsFromThem,
    required this.endorsementsToThem,
    this.recommendationFromThem,
    this.recommendationToThem,
    this.invitationOnly = false,
    this.invitationDirection = 'OUTGOING',
    this.invitationNeverAccepted = false,
    this.threadTitle,
    this.thread = const [],
  });

  final String first;
  final String last;
  final String slug;
  final String company;
  final String position;
  final String headline;
  final String summary;

  /// `dd MMM yyyy` format, matches LinkedIn's Connections.csv format.
  final String connectedOn;

  /// Skill names this persona endorsed Ada for.
  final List<String> endorsementsFromThem;

  /// Skill names Ada endorsed them for.
  final List<String> endorsementsToThem;

  /// Multi-paragraph recommendation written by them, about Ada.
  final String? recommendationFromThem;

  /// Written by Ada, about them.
  final String? recommendationToThem;

  /// If true, they never accepted the connection — render as a pending
  /// invitation only (e.g. Ada's estranged father Byron).
  final bool invitationOnly;
  final String invitationDirection;
  final bool invitationNeverAccepted;

  /// If set, generates a conversation between Ada and them. The thread is
  /// a list of ScriptedMessage; "fromAda" is true when Ada wrote the line.
  final String? threadTitle;
  final List<ScriptedMessage> thread;

  String get fullName => '$first $last';
  String get profileUrl => 'https://www.linkedin.com/in/$slug';
}

class ScriptedMessage {
  const ScriptedMessage({
    required this.fromAda,
    required this.date,
    this.subject = '',
    required this.content,
    this.isDraft = false,
  });

  final bool fromAda;

  /// Any string in the form `YYYY-MM-DD HH:MM` (UTC assumed).
  final String date;
  final String subject;
  final String content;
  final bool isDraft;
}

/// Ada Byron-Lovelace is the "me" identity in the demo export.
const meFirstName = 'Ada';
const meLastName = 'Byron-Lovelace';
const meSlug = 'fake-ada-byron-lovelace';
const meHeadline =
    'Analytical Engineer · Bernoulli number automation · '
    'Translating abstract compute into operational reality';
const meSummary =
    'Mathematically-trained generalist working at the intersection of '
    'symbolic notation and mechanical computation. Currently collaborating '
    'with an early-stage founder on a general-purpose Analytical Engine; '
    'my Translator\'s Notes to the 1842 paper are generally considered '
    'the first published programme.\n\n'
    'Previously: Translator, private tutor in differential calculus, '
    'occasional correspondent to the Royal Astronomical Society.\n\n'
    'Interests: operational cards, recursive notation, the generalisation '
    'of calculation beyond arithmetic, horses.\n\n'
    'Open to: consulting on symbolic reasoning and programme flow. '
    'Not open to: poetry.';

const personas = <Persona>[
  // --------------------------------------------------------------------
  Persona(
    first: 'Charles',
    last: 'Babbage',
    slug: 'fake-charles-babbage',
    company: 'Analytical Engines (stealth)',
    position: 'Founder & CTO',
    headline:
        'Founder · Inventor · Professionally frustrated · '
        'Difference Engine (prev.) · Analytical Engine (current) · Royal Society',
    summary:
        'Building general-purpose mechanical computation. Ask me about '
        'operation cards, the mill, and why the Treasury no longer returns '
        'my letters.\n\n'
        'Currently fundraising. Always fundraising.',
    connectedOn: '05 Jun 1833',
    endorsementsFromThem: [
      'Notation',
      'Operational Cards',
      'Debugging',
      'Translation',
      'Stakeholder Management',
    ],
    endorsementsToThem: ['Mechanical Engineering', 'Fundraising'],
    recommendationFromThem:
        'Ada\'s Translator\'s Notes to my Analytical Engine paper were, '
        'if I am honest, an improvement on the source material. She is the '
        'only person I know who genuinely understands the mill, and the '
        'only person who replies to my letters on time. I would hire her '
        'again without hesitation, except that she works for no one.',
    threadTitle: 'Re: Bernoulli programme',
    thread: [
      ScriptedMessage(
        fromAda: true,
        date: '1842-07-10 09:14',
        subject: 'Bernoulli programme — card sets 7-12',
        content:
            'Charles,\n\nAttaching my notes on the Bernoulli sequence '
            'programme. Can we step through card sets 7 through 12?\n\n'
            'Two things bothering me:\n'
            '1. Carry-forward on the mill when the store overflows.\n'
            '2. Whether operations 11 and 12 can be collapsed.\n\n'
            '— A.',
      ),
      ScriptedMessage(
        fromAda: false,
        date: '1842-07-10 18:02',
        content:
            'Ada,\n\nReceived. Your notation is clearer than mine. Can we '
            'sync Tuesday at the Royal Institution? I\'ll bring the revised '
            'operation cards.\n\nC.',
      ),
      ScriptedMessage(
        fromAda: true,
        date: '1842-07-11 07:40',
        content:
            'Tuesday 3pm works. I\'ll bring my Translation draft. '
            'One concern: if the mill overflows, what\'s the current '
            'failure mode?',
      ),
      ScriptedMessage(
        fromAda: false,
        date: '1842-07-11 09:11',
        content:
            'Present failure mode: I walk to the window and look out of it.',
      ),
      ScriptedMessage(
        fromAda: true,
        date: '1842-07-11 09:34',
        content: 'Understood. I\'ll draft a carry-forward pattern.',
      ),
    ],
  ),

  // --------------------------------------------------------------------
  Persona(
    first: 'Mary',
    last: 'Somerville',
    slug: 'fake-mary-somerville',
    company: 'Independent',
    position: 'Principal Scientist',
    headline:
        'Science Generalist · Author, On the Connexion of the Physical '
        'Sciences · Fellow, Royal Astronomical Society',
    summary:
        'Writing. Mentoring. Occasionally translating Laplace.\n\n'
        'My mentees have done well.',
    connectedOn: '22 Mar 1833',
    endorsementsFromThem: ['Analytical Thinking', 'Mathematics', 'Perseverance'],
    endorsementsToThem: ['Writing', 'Mentoring', 'Astronomy'],
    recommendationFromThem:
        'I have tutored many capable students. Ada is one of them.',
    recommendationToThem:
        'Mary introduced me to Charles, to mathematics taken seriously, '
        'and to the idea that a woman might publish without apology. Her '
        'work on celestial mechanics does not need my endorsement, but it '
        'has it.',
    threadTitle: '',
    thread: [
      ScriptedMessage(
        fromAda: true,
        date: '1841-11-02 10:05',
        content:
            'Mary — I finally posted my Translator\'s Notes to Charles. '
            'He says "an improvement on the source material." I do not know '
            'what to do with that compliment.',
      ),
      ScriptedMessage(
        fromAda: false,
        date: '1841-11-02 14:30',
        content:
            'File it. He will be difficult for a month and then write to '
            'ask if you are free to revise.',
      ),
    ],
  ),

  // --------------------------------------------------------------------
  Persona(
    first: 'Michael',
    last: 'Faraday',
    slug: 'fake-michael-faraday',
    company: 'Royal Institution',
    position: 'Chief Electromagnetic Officer',
    headline:
        'Electromagnetic induction · Field theory · Public science '
        'communications · Christmas Lecturer',
    summary:
        'I bind the invisible forces of nature to mathematical law, and I '
        'host a lecture series for children at Christmas.\n\n'
        'Open to collaborations. Tuesdays only.',
    connectedOn: '18 Oct 1843',
    endorsementsFromThem: ['Mathematics', 'Symbolic Reasoning'],
    endorsementsToThem: ['Public Speaking', 'Experimental Method'],
    threadTitle: '',
    thread: [
      ScriptedMessage(
        fromAda: false,
        date: '1844-01-16 19:45',
        subject: 'Note G',
        content:
            'Enjoyed your Note G. I am not a mathematician, but I am now '
            'slightly less not-a-mathematician.',
      ),
      ScriptedMessage(
        fromAda: true,
        date: '1844-01-17 08:10',
        content:
            'Michael — coming from you that is an extraordinary kindness.',
      ),
      ScriptedMessage(
        fromAda: false,
        date: '1844-01-17 09:50',
        content:
            'Would you be willing to visit the Royal Institution? I have '
            'a device for Tuesdays.',
      ),
    ],
  ),

  // --------------------------------------------------------------------
  Persona(
    first: 'Florence',
    last: 'Nightingale',
    slug: 'fake-florence-nightingale',
    company: 'London hospital system',
    position: 'Senior Director, Patient Outcomes',
    headline:
        'Evidence-based nursing · Polar-area diagrams · Hospital sanitation',
    summary:
        'Data-driven healthcare. If you can\'t measure it, the patient dies. '
        'If you can measure it, the patient probably still dies — but for '
        'reasons we can now discuss at a committee meeting.',
    connectedOn: '14 May 1852',
    endorsementsFromThem: ['Data Visualisation', 'Analytical Thinking'],
    endorsementsToThem: ['Statistics', 'Operational Excellence'],
    threadTitle: 'Re: Mortality pamphlet',
    thread: [
      ScriptedMessage(
        fromAda: false,
        date: '1852-05-14 11:02',
        content:
            'Ada — I\'ve seen your Translator\'s Notes. The rhetorical line '
            'about the engine weaving "algebraic patterns just as the '
            'Jacquard loom weaves flowers" — are you open to adapting this '
            'for a pamphlet on hospital mortality?',
      ),
      ScriptedMessage(
        fromAda: true,
        date: '1852-05-14 15:20',
        content: 'Flo, happy to. Which figures should I weave?',
      ),
      ScriptedMessage(
        fromAda: false,
        date: '1852-05-14 15:34',
        content: 'Crimean winter mortality.',
      ),
      ScriptedMessage(
        fromAda: true,
        date: '1852-05-14 15:58',
        content: 'Grim but tractable. Sending thoughts by Tuesday.',
      ),
    ],
  ),

  // --------------------------------------------------------------------
  Persona(
    first: 'Augustus',
    last: 'De Morgan',
    slug: 'fake-augustus-de-morgan',
    company: 'University College London',
    position: 'Principal Tutor, Symbolic Logic',
    headline:
        'Mathematician · Logician · Author of the "On the Syllogism" series '
        '· Tutoring available',
    summary:
        'Pure and applied mathematics instructor. Former tutor to A. Byron. '
        'Please read "On the Syllogism, II" before reaching out.',
    connectedOn: '11 Feb 1840',
    endorsementsFromThem: ['Symbolic Logic', 'Perseverance'],
    endorsementsToThem: ['Mathematics Education', 'Logic'],
    recommendationFromThem:
        'An able analyst. If she applied herself exclusively to '
        'mathematics, she would become a first-rate original investigator. '
        'Whether this is desirable, I remain ambivalent.',
    threadTitle: '',
    thread: [
      ScriptedMessage(
        fromAda: false,
        date: '1841-03-09 08:20',
        subject: 'Continuity of functions',
        content:
            'Ada — received your last on the continuity of functions. '
            'Correct on 3 of 4. See attached.',
      ),
      ScriptedMessage(
        fromAda: true,
        date: '1841-03-09 14:40',
        content: 'Which one was wrong?',
      ),
      ScriptedMessage(
        fromAda: false,
        date: '1841-03-09 17:05',
        content: 'I\'ve left that as an exercise for the reader.',
      ),
    ],
  ),

  // --------------------------------------------------------------------
  Persona(
    first: 'John',
    last: 'Herschel',
    slug: 'fake-john-herschel',
    company: 'Royal Observatory',
    position: 'Chief Astronomer',
    headline:
        'Astronomy · Photography · Chemistry · Whatever Cambridge needs',
    summary:
        'I coined "photograph." I mapped most of the southern sky. I am '
        'often asked about my father. I knew Ada.',
    connectedOn: '29 Aug 1835',
    endorsementsFromThem: ['Analytical Thinking', 'Symbolic Reasoning'],
    endorsementsToThem: ['Astronomy', 'Photography', 'Patience'],
    threadTitle: '',
    thread: [
      ScriptedMessage(
        fromAda: true,
        date: '1843-09-12 10:15',
        content:
            'John — any read on whether the engine might plot stellar '
            'tables directly? Charles thinks yes; I think yes with caveats.',
      ),
      ScriptedMessage(
        fromAda: false,
        date: '1843-09-13 06:40',
        content:
            'In principle, yes. In practice, come and see my tables. '
            'They are not computed; they are negotiated.',
      ),
    ],
  ),

  // --------------------------------------------------------------------
  Persona(
    first: 'William',
    last: 'Whewell',
    slug: 'fake-william-whewell',
    company: 'Trinity College, Cambridge',
    position: 'Master',
    headline:
        'Philosopher of science · Coined "scientist" · Tidology · '
        'Historian of the inductive sciences',
    summary: 'I named your profession.',
    connectedOn: '02 May 1836',
    endorsementsFromThem: ['Writing', 'Philosophy of Science'],
    endorsementsToThem: ['Taxonomy', 'Academic Politics'],
    threadTitle: '',
    thread: [],
  ),

  // --------------------------------------------------------------------
  Persona(
    first: 'Charles',
    last: 'Dickens',
    slug: 'fake-charles-dickens',
    company: 'Household Words',
    position: 'Senior Novelist & Editor',
    headline: 'Storyteller · Campaigner · Publisher of Household Words',
    summary:
        'It was the best of networking platforms, it was the worst of '
        'networking platforms.',
    connectedOn: '06 Jun 1840',
    endorsementsFromThem: ['Writing', 'Public Speaking'],
    endorsementsToThem: ['Storytelling', 'Serial Publication'],
    threadTitle: 'Re: Reading request',
    thread: [
      ScriptedMessage(
        fromAda: false,
        date: '1844-04-03 16:00',
        content:
            'Would you be available on the evening of the 17th? Reading '
            'the closing of Martin Chuzzlewit at Lady Blessington\'s. I am '
            'told you do not attend these; I am asking anyway.',
      ),
      ScriptedMessage(
        fromAda: true,
        date: '1844-04-03 20:20',
        content:
            'Thank you — calendar permitting. Is there a written copy I '
            'might read in advance? I find readings work better for me '
            'with prior exposure to the material.',
      ),
      ScriptedMessage(
        fromAda: false,
        date: '1844-04-03 22:00',
        content: 'No.',
      ),
    ],
  ),

  // --------------------------------------------------------------------
  Persona(
    first: 'Mary',
    last: 'Shelley',
    slug: 'fake-mary-shelley',
    company: 'Independent',
    position: 'Senior Novelist',
    headline:
        'Novelist · "Frankenstein" (1818, now on 3rd edition) · '
        'Editor, Byron literary estate',
    summary:
        'Fiction, editing, estate management. Open to speaking engagements. '
        'Not about Percy.',
    connectedOn: '17 Jan 1842',
    endorsementsFromThem: ['Symbolic Reasoning'],
    endorsementsToThem: ['Writing', 'Editing'],
    threadTitle: '',
    thread: [
      ScriptedMessage(
        fromAda: false,
        date: '1843-02-22 11:45',
        content:
            'Ada — working through the last of your father\'s drafts this '
            'season. Would you like first refusal on any of the unpublished '
            'material?',
      ),
      ScriptedMessage(
        fromAda: true,
        date: '1843-02-22 12:30',
        content: 'No, thank you. Grateful you asked.',
      ),
    ],
  ),

  // --------------------------------------------------------------------
  // Lord Byron — absentee father, died when Ada was 8. He never accepts
  // the connection. This is the piece that lands hardest: the comedy
  // vanishes into melancholy if you sit with it, which is the point.
  Persona(
    first: 'Lord',
    last: 'Byron',
    slug: 'fake-lord-byron',
    company: 'No longer accepting engagements',
    position: 'Poet (on indefinite leave)',
    headline:
        'Poet · Traveller · Greek War of Independence (volunteer) · '
        'Out of office indefinitely',
    summary:
        'Currently in Missolonghi. Back-channel via Lady Byron.',
    connectedOn: '',
    endorsementsFromThem: [],
    endorsementsToThem: [],
    invitationOnly: true,
    invitationDirection: 'OUTGOING',
    invitationNeverAccepted: true,
    threadTitle: '',
    thread: [],
  ),
];
