import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkedin_export_viewer/main.dart';

void main() {
  testWidgets('landing screen renders the upload and demo entry points',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: LinkedInExportViewerApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('LinkedOut!'), findsOneWidget);
    expect(find.text('Upload your LinkedIn zip'), findsOneWidget);
    expect(find.text('Try with sample data'), findsOneWidget);
  });
}
