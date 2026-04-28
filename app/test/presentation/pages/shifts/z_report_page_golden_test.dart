import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_bloc.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_event.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_state.dart';
import 'package:dukonpro/presentation/pages/shifts/z_report_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockShiftBloc extends MockBloc<ShiftEvent, ShiftState>
    implements ShiftBloc {}

void main() {
  late _MockShiftBloc shiftBloc;

  setUp(() {
    shiftBloc = _MockShiftBloc();
    when(() => shiftBloc.state).thenReturn(ShiftInitial());
  });

  tearDown(() {
    shiftBloc.close();
  });

  Widget page() => const ZReportPage(
        storeId: 'test-store-id',
        shiftId: 'test-shift-id',
      );

  Widget wrapWithBlocs(Widget child) => BlocProvider<ShiftBloc>.value(
        value: shiftBloc,
        child: child,
      );

  group('ZReportPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'z_report_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'z_report_dark');
    });
  });
}
