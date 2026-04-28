import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/printer/printer_bloc.dart';
import 'package:dukonpro/presentation/blocs/printer/printer_event.dart';
import 'package:dukonpro/presentation/blocs/printer/printer_state.dart';
import 'package:dukonpro/presentation/pages/settings/printer_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockPrinterBloc extends MockBloc<PrinterEvent, PrinterState>
    implements PrinterBloc {}

void main() {
  late _MockPrinterBloc printerBloc;

  setUp(() {
    printerBloc = _MockPrinterBloc();
    when(() => printerBloc.state).thenReturn(const PrinterState());
  });

  tearDown(() {
    printerBloc.close();
  });

  Widget wrapWithBloc(Widget child) => BlocProvider<PrinterBloc>.value(
        value: printerBloc,
        child: child,
      );

  Widget page() => const PrinterSettingsPage();

  group('PrinterSettingsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBloc,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'printer_settings_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBloc,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'printer_settings_dark');
    });
  });
}
