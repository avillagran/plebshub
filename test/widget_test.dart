import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plebshub/app/app.dart';

void main() {
  testWidgets('PlebsHub app launches successfully', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PlebsHubApp(),
      ),
    );

    // Verify app title is displayed
    expect(find.text('PlebsHub'), findsOneWidget);
  });
}
