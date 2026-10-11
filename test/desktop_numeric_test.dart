import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:detergent_factory/widgets/custom_numeric_widgets.dart';

void main() {
  testWidgets(
      'Desktop keyboard normalizes Arabic numbers and clears stale values',
      (tester) async {
    double value = 12;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.windows),
      home: Scaffold(
          body: CustomNumericField(
              label: 'Quantity',
              initialValue: 12,
              onChanged: (v) => value = v)),
    ));
    await tester.enterText(find.byType(TextField), '١٢٫٥');
    expect(value, 12.5);
    await tester.enterText(find.byType(TextField), '');
    expect(value, 0);
    await tester.enterText(find.byType(TextField), '-1');
    expect(value, 0);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
