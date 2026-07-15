import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:dukonpro/presentation/widgets/common/barcode_scanner_sheet.dart';

import '../../../helpers/golden_pump_helper.dart';

// mobile_scanner uses two channels that have no platform implementation in the
// test environment. Mock both so the widget builds + disposes without throwing.
const _methodChannel =
    MethodChannel('dev.steenbakker.mobile_scanner/scanner/method');
const _eventChannel =
    EventChannel('dev.steenbakker.mobile_scanner/scanner/event');

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          _eventChannel,
          MockStreamHandler.inline(
            onListen: (_, _) {},
            onCancel: (_) {},
          ),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(_eventChannel, null);
  });

  group('BarcodeScannerSheet goldens', () {
    Widget sample() => BarcodeScannerSheet(onScanned: (_) {});

    testGoldens('light theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.light,
        alignment: Alignment.bottomCenter,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'barcode_scanner_sheet_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWidgetWithTheme(
        tester,
        sample(),
        brightness: Brightness.dark,
        alignment: Alignment.bottomCenter,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'barcode_scanner_sheet_dark');
    });
  });
}
