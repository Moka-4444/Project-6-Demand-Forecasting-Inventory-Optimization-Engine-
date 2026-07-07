import 'package:flutter_test/flutter_test.dart';
import 'package:stocksense/main.dart';

void main() {
  testWidgets('StockSense app loads splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const StockSenseApp());
    expect(find.text('StockSense'), findsOneWidget);
  });
}
