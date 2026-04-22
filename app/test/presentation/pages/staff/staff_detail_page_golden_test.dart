import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/shift/shift_bloc.dart';
import 'package:dokonpro/presentation/blocs/shift/shift_event.dart';
import 'package:dokonpro/presentation/blocs/shift/shift_state.dart';
import 'package:dokonpro/presentation/blocs/staff/staff_bloc.dart';
import 'package:dokonpro/presentation/blocs/staff/staff_event.dart';
import 'package:dokonpro/presentation/blocs/staff/staff_state.dart';
import 'package:dokonpro/presentation/pages/staff/staff_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockStaffBloc extends MockBloc<StaffEvent, StaffState>
    implements StaffBloc {}

class _MockShiftBloc extends MockBloc<ShiftEvent, ShiftState>
    implements ShiftBloc {}

void main() {
  late _MockStaffBloc staffBloc;
  late _MockShiftBloc shiftBloc;

  setUp(() {
    staffBloc = _MockStaffBloc();
    shiftBloc = _MockShiftBloc();
    when(() => staffBloc.state).thenReturn(StaffInitial());
    when(() => shiftBloc.state).thenReturn(ShiftInitial());
  });

  tearDown(() {
    staffBloc.close();
    shiftBloc.close();
  });

  Widget page() => const StaffDetailPage(
        storeId: 'test-store-id',
        staffId: 'test-staff-id',
      );

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StaffBloc>.value(value: staffBloc),
          BlocProvider<ShiftBloc>.value(value: shiftBloc),
        ],
        child: child,
      );

  group('StaffDetailPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'staff_detail_light');
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
      await screenMatchesGolden(tester, 'staff_detail_dark');
    });
  });
}
