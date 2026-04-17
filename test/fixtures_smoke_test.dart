// Smoke-test the synthetic fixtures produced by tool/generate_fixture.dart.
// Confirms every expected file exists, headers match the real LinkedIn export
// byte-for-byte, row counts fall in reasonable ranges, and no PII slipped in.

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:test/test.dart';

const _dir = 'fixtures/sample_export';
const _zip = 'fixtures/sample_export.zip';

/// Expected headers, copied verbatim from the real LinkedIn export schema.
/// Any drift here indicates the generator fell out of sync with the real format.
const _expectedHeaders = <String, String>{
  'Ad_Targeting.csv':
      'Member Age,Buyer Groups,Company Names,Company Names,Company Follower of,Company Names,Company Category,Company Size,Degrees,degreeClass,Recent Device OS,Member Schools,Company Growth Rate,Fields of Study,Company Connections,Function By Size,Job Functions,Member Gender,Graduation Year,Member Groups,Company Industries,Member Interests,Interface Locales,interfaceLocale,Member Traits,High Value Audience Segments,Profile Locations,Company Revenue,Job Seniorities,Member Skills,Standard Audience Segments,Job Titles,Job Titles,Job Titles,Years of Experience',
  'Company Follows.csv': 'Organization,Followed On',
  'Education.csv': 'School Name,Start Date,End Date,Notes,Degree Name,Activities',
  'Email Addresses.csv': 'Email Address,Confirmed,Primary,Updated On',
  'Endorsement_Given_Info.csv':
      'Endorsement Date,Skill Name,Endorsee First Name,Endorsee Last Name,Endorsee Public Url,Endorsement Status',
  'Endorsement_Received_Info.csv':
      'Endorsement Date,Skill Name,Endorser First Name,Endorser Last Name,Endorser Public Url,Endorsement Status',
  'Events.csv': 'Event Name,Event Time,Status,External Url',
  'guide_messages.csv':
      'CONVERSATION ID,CONVERSATION TITLE,FROM,SENDER PROFILE URL,TO,RECIPIENT PROFILE URLS,DATE,SUBJECT,CONTENT,FOLDER',
  'Invitations.csv':
      'From,To,Sent At,Message,Direction,inviterProfileUrl,inviteeProfileUrl',
  'Job Applicant Saved Screening Question Responses.csv': 'Question,Answer',
  'Languages.csv': 'Name,Proficiency',
  'learning_role_play_messages.csv':
      'CONVERSATION ID,CONVERSATION TITLE,FROM,SENDER PROFILE URL,TO,RECIPIENT PROFILE URLS,DATE,SUBJECT,CONTENT,FOLDER',
  'Learning.csv':
      'Content Title,Content Description,Content Type,Content Last Watched Date (if viewed),Content Completed At (if completed),Content Saved,Notes taken on videos (if taken),',
  'messages.csv':
      'CONVERSATION ID,CONVERSATION TITLE,FROM,SENDER PROFILE URL,TO,RECIPIENT PROFILE URLS,DATE,SUBJECT,CONTENT,FOLDER,ATTACHMENTS,IS MESSAGE DRAFT',
  'PhoneNumbers.csv': 'Extension,Number,Type',
  'Positions.csv': 'Company Name,Title,Description,Location,Started On,Finished On',
  'Private_identity_asset.csv':
      'Private Identity Asset Name,Private Identity Asset Raw Text',
  'Profile Summary.csv': 'Profile Summary',
  'Profile.csv':
      'First Name,Last Name,Maiden Name,Address,Birth Date,Headline,Summary,Industry,Zip Code,Geo Location,Twitter Handles,Websites,Instant Messengers',
  'Projects.csv': 'Title,Description,Url,Started On,Finished On',
  'Publications.csv': 'Name,Published On,Description,Publisher,Url',
  'Receipts_v2.csv':
      'First Name,Last Name,Billing Country,Postal Code,Transaction Made At,Payment Method Type,Invoice Number,Description,Tax Amount,Sub Total,Total Amount,Currency Code',
  'Recommendations_Given.csv':
      'First Name,Last Name,Company,Job Title,Text,Creation Date,Status',
  'Recommendations_Received.csv':
      'First Name,Last Name,Company,Job Title,Text,Creation Date,Status',
  'Registration.csv': 'Registered At,Registration Ip,Subscription Types',
  'Rich_Media.csv': 'Date/Time,Media Description,Media Link',
  'SavedJobAlerts.csv': 'ALERT_PARAMETERS,QUERY_CONTEXT,SAVED_SEARCH_ID',
  'Skills.csv': 'Name',
  'Whatsapp Phone Numbers.csv': 'Number,Extension,Is_WhatsApp_Number',
  'Jobs/Job Applicant Saved Answers.csv': 'Question,Answer',
  'Jobs/Job Applications.csv':
      'Application Date,Contact Email,Contact Phone Number,Company Name,Job Title,Job Url,Resume Name,Question And Answers',
  'Jobs/Job Seeker Preferences.csv':
      'Locations,Industries,Company Employee Count,Preferred Job Types,Job Titles,Open To Recruiters,Dream Companies,Profile Shared With Job Poster,Job Title For Searching Fast Growing Companies,Introduction Statement,Phone Number,Job Seeker Activity Level,Preferred Start Time Range,Commute Preference Starting Address,Commute Preference Starting Time,Mode Of Transportation,Maximum Commute Duration,Open Candidate Visibility,Job Seeking Urgency Level',
  'Jobs/Saved Jobs.csv': 'Saved Date,Job Url,Job Title,Company Name',
  'Verifications/Verifications.csv':
      'First name,Middle name,Last name,Verification type,Organization name,Email address,Country,State,City,Year of birth,Issuing authority,Document type,Verification service provider,Verified date,Expiry date',
};

/// (inclusive min, inclusive max) expected data row counts per file.
/// Ranges leave slack so small generator tweaks don't break the test.
const _rowRanges = <String, (int, int)>{
  'Ad_Targeting.csv': (1, 1),
  'Company Follows.csv': (40, 80),
  'Education.csv': (1, 5),
  'Email Addresses.csv': (1, 5),
  'Endorsement_Given_Info.csv': (1000, 2000),
  'Endorsement_Received_Info.csv': (500, 1000),
  'Events.csv': (5, 20),
  'Invitations.csv': (100, 250),
  'Job Applicant Saved Screening Question Responses.csv': (3, 15),
  'Languages.csv': (1, 5),
  'Learning.csv': (100, 250),
  'messages.csv': (15000, 25000),
  'PhoneNumbers.csv': (1, 6),
  'Positions.csv': (5, 20),
  'Private_identity_asset.csv': (1, 2),
  'Profile Summary.csv': (1, 1),
  'Profile.csv': (1, 1),
  'Projects.csv': (10, 30),
  'Publications.csv': (1, 5),
  'Receipts_v2.csv': (5, 20),
  'Recommendations_Given.csv': (15, 40),
  'Recommendations_Received.csv': (20, 50),
  'Registration.csv': (1, 1),
  'Rich_Media.csv': (100, 300),
  'SavedJobAlerts.csv': (3, 10),
  'Skills.csv': (40, 80),
  'Whatsapp Phone Numbers.csv': (1, 3),
  'Jobs/Job Applicant Saved Answers.csv': (1, 3),
  'Jobs/Job Applications.csv': (15, 40),
  'Jobs/Job Seeker Preferences.csv': (1, 1),
  'Jobs/Saved Jobs.csv': (3, 15),
  'Verifications/Verifications.csv': (1, 3),
};

void main() {
  test('fixtures directory exists', () {
    expect(Directory(_dir).existsSync(), isTrue,
        reason: 'Run `dart run tool/generate_fixture.dart` first.');
  });

  test('fixtures zip exists and is non-trivially sized', () {
    final zip = File(_zip);
    expect(zip.existsSync(), isTrue);
    expect(zip.lengthSync(), greaterThan(10000));
  });

  group('headers match the real LinkedIn export byte-for-byte', () {
    for (final entry in _expectedHeaders.entries) {
      test(entry.key, () {
        final file = File('$_dir/${entry.key}');
        expect(file.existsSync(), isTrue, reason: 'Missing: ${entry.key}');
        final firstLine = file.readAsLinesSync().first;
        expect(firstLine, entry.value,
            reason: 'Header drift in ${entry.key}');
      });
    }
  });

  test('Connections.csv has a Notes: preamble block before column headers', () {
    final lines = File('$_dir/Connections.csv').readAsLinesSync();
    expect(lines[0], 'Notes:');
    expect(lines[1], startsWith('"'));
    expect(lines.firstWhere((l) => l.startsWith('First Name,Last Name,URL,')),
        isNotNull);
  });

  test('Connections.csv has a realistic number of contacts', () {
    final lines = File('$_dir/Connections.csv').readAsLinesSync();
    final headerIndex = lines.indexWhere((l) => l.startsWith('First Name,Last Name,URL,'));
    final dataRows = lines.length - headerIndex - 1;
    expect(dataRows, inInclusiveRange(1500, 2500));
  });

  test('Articles folder has HTML files', () {
    final dir = Directory('$_dir/Articles/Articles');
    expect(dir.existsSync(), isTrue);
    final htmls = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.html')).toList();
    expect(htmls.length, greaterThanOrEqualTo(3));
    for (final f in htmls) {
      final content = f.readAsStringSync();
      expect(content, contains('<html'));
      expect(content, contains('</html>'));
    }
  });

  test('Ad_Targeting.csv has the real schema with duplicate columns', () {
    final headerLine = File('$_dir/Ad_Targeting.csv').readAsLinesSync().first;
    final headers = headerLine.split(',');
    expect(headers.where((h) => h == 'Company Names').length, 3);
    expect(headers.where((h) => h == 'Job Titles').length, 3);
    expect(headers, contains('degreeClass'));
    expect(headers, contains('interfaceLocale'));
  });

  group('row counts fall in expected ranges', () {
    for (final entry in _rowRanges.entries) {
      test(entry.key, () {
        final file = File('$_dir/${entry.key}');
        expect(file.existsSync(), isTrue);
        final rows = const CsvToListConverter(
          eol: '\n',
          shouldParseNumbers: false,
        ).convert(file.readAsStringSync());
        // Header row (plus, for Connections.csv, the Notes: preamble we skip).
        final dataRows = entry.key == 'Connections.csv'
            ? rows.where((r) => r.length >= 7).length - 1
            : rows.length - 1;
        final (min, max) = entry.value;
        expect(dataRows, inInclusiveRange(min, max),
            reason: '${entry.key} had $dataRows data rows');
      });
    }
  });

  test('guide_messages.csv and learning_role_play_messages.csv have no data rows', () {
    final guide = File('$_dir/guide_messages.csv').readAsLinesSync();
    final roleplay = File('$_dir/learning_role_play_messages.csv').readAsLinesSync();
    expect(guide.length, 1);
    expect(roleplay.length, 1);
  });

  test('no recognizable real PII patterns slipped in', () {
    // Sanity check across a few representative files. If the generator ever
    // reaches for real data this catches obvious leakage.
    const checks = [
      'Connections.csv',
      'messages.csv',
      'Profile.csv',
      'Email Addresses.csv',
    ];
    final redFlags = <RegExp>[
      RegExp(r'@gmail\.com', caseSensitive: false),
      RegExp(r'@yahoo\.com', caseSensitive: false),
      RegExp(r'@outlook\.com', caseSensitive: false),
      RegExp(r'@hotmail\.com', caseSensitive: false),
      RegExp(r'@icloud\.com', caseSensitive: false),
      RegExp(r'silkyrich', caseSensitive: false),
    ];
    for (final path in checks) {
      final contents = File('$_dir/$path').readAsStringSync();
      for (final flag in redFlags) {
        expect(flag.hasMatch(contents), isFalse,
            reason: 'Suspect pattern ${flag.pattern} found in $path');
      }
    }
  });
}

