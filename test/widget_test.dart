import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/app.dart';

void main() {
  testWidgets('renders the offline application skeleton', (tester) async {
    await tester.pumpWidget(const TemplateApp());
    expect(find.text('Flutter Template'), findsOneWidget);
  });
}
