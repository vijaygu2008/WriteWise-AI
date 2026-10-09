import 'package:flutter_test/flutter_test.dart';
import 'package:writewiseai/main.dart';

void main() {
  testWidgets('WriteWise AI loads', (WidgetTester tester) async {
    await tester.pumpWidget(const WriteWiseAI());

    expect(find.text('WriteWise AI'), findsWidgets);
  });
}