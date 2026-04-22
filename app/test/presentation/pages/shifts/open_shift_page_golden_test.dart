import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/shift/shift_bloc.dart';
import 'package:dokonpro/presentation/blocs/shift/shift_event.dart';
import 'package:dokonpro/presentation/blocs/shift/shift_state.dart';
import 'package:dokonpro/presentation/pages/shifts/open_shift_page.dart';
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

  Widget page() => const OpenShiftPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => BlocProvider<ShiftBloc>.value(
        value: shiftBloc,
        child: child,
      );

  group('OpenShiftPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'open_shift_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'open_shift_dark');
    });
  });
}
