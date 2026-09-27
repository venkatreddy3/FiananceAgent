import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/storage_service.dart';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('fintrack_test_');
    await StorageService().initialize(tempDir.path);
  });

  testWidgets('FinTrack app launches and displays AppEntryRouter', (WidgetTester tester) async {
    await tester.pumpWidget(const FinTrackApp());
    await tester.pumpAndSettle();

    expect(find.byType(FinTrackApp), findsOneWidget);
    expect(find.byType(AppEntryRouter), findsOneWidget);
  });
}
