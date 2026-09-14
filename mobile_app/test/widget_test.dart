import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('Splash screen shows HOFIS branding', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HofisAttendanceApp());

    // Verify that HOFIS branding is rendered on the first page
    expect(find.text('HOFIS'), findsOneWidget);
    expect(find.text('Higher Order Future Indian School'), findsOneWidget);
  });
}
