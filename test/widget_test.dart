import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cheers/app.dart';

void main() {
  testWidgets('Cheers boots and shows the home heading', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CheersApp()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Cheers'), findsOneWidget);
  });
}
