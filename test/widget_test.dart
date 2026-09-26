import 'package:flutter_test/flutter_test.dart';
import 'package:ma_belle_semaine/main.dart';

void main() {
  testWidgets('MyBestWeek démarre', (tester) async {
    await tester.pumpWidget(const MaBelleSemaineApp());
    expect(find.text('Accueil'), findsOneWidget);
  });
}
