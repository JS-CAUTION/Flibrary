import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/widgets/origami_crane.dart';

void main() {
  testWidgets('OrigamiCrane renders at various sizes without errors',
      (tester) async {
    for (final size in [24.0, 48.0, 72.0, 96.0, 144.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: OrigamiCrane(size: size))),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(OrigamiCrane), findsOneWidget);
    }
  });
}
