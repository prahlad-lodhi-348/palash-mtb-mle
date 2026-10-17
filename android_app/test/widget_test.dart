import 'package:flutter_test/flutter_test.dart';
import 'package:palash_mtb_mle/main.dart';

void main() {
  testWidgets('shows the PALASH home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PalashApp());

    expect(find.text('PALASH MTB-MLE'), findsOneWidget);
    expect(find.text('Open Integration Demo'), findsOneWidget);
  });
}
