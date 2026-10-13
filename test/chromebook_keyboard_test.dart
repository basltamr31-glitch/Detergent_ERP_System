import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:detergent_factory/widgets/custom_numeric_widgets.dart';

void main() {
  testWidgets(
      'Android/ChromeOS keyboard works in a narrow window and optional keypad preserves Arabic decimals',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    double value = 0;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
            body: CustomNumericField(
                label: 'Quantity', onChanged: (v) => value = v))));
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).readOnly, false);
    await tester.enterText(field, '١٢٫٥');
    expect(value, 12.5);
    await tester.tap(find.byIcon(Icons.dialpad));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(value, 12.5);
    await tester.enterText(find.byType(TextField), '');
    expect(value, 0);
    expect(tester.takeException(), isNull);
  });
}
