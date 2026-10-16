import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/data/thai_airlines.dart';
import 'package:mini_projects/widgets/airline_logo.dart';

void main() {
  test('every Thai airline has an image asset', () {
    for (final airline in thaiAirlines) {
      expect(File(airline.logoAsset).existsSync(), isTrue, reason: airline.code);
    }
  });

  testWidgets('known airline shows its image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AirlineLogo(airlineName: 'Thai Airways', flightNumber: 'TG102'),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/airlines/TG.png');
    expect(find.bySemanticsLabel('Thai Airways'), findsOneWidget);
  });

  testWidgets('unknown airline falls back to a letter badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AirlineLogo(airlineName: 'Other Air', flightNumber: 'ZZ1'),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.text('O'), findsOneWidget);
  });
}
