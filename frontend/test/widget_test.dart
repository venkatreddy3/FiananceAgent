import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('FinTrack app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FinTrackApp());
    await tester.pumpAndSettle();

    // Verify app launches successfully and displays title
    expect(find.text('FinTrack AI'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
  });
}
