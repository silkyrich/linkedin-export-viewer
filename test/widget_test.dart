import 'package:flutter_test/flutter_test.dart';
import 'package:linkedin_export_viewer/main.dart';

void main() {
  testWidgets('bootstrap screen renders app title', (tester) async {
    await tester.pumpWidget(const LinkedInExportViewerApp());
    expect(find.text('LinkedIn Export Viewer'), findsOneWidget);
  });
}
