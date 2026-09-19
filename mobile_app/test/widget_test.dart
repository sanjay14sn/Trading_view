import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TradingViewAlgoApp());
    expect(find.text('TradingView Algo'), findsWidgets);
  });
}
