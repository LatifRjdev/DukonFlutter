import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/staff/staff_bloc.dart';
import 'package:dokonpro/presentation/blocs/staff/staff_event.dart';
import 'package:dokonpro/presentation/blocs/staff/staff_state.dart';
import 'package:dokonpro/presentation/blocs/staff_form/staff_form_bloc.dart';
import 'package:dokonpro/presentation/blocs/staff_form/staff_form_event.dart';
import 'package:dokonpro/presentation/blocs/staff_form/staff_form_state.dart';
import 'package:dokonpro/presentation/pages/staff/add_staff_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockStaffBloc extends MockBloc<StaffEvent, StaffState>
    implements StaffBloc {}

class _MockStaffFormBloc extends MockBloc<StaffFormEvent, StaffFormState>
    implements StaffFormBloc {}

void main() {
  late _MockStaffBloc staffBloc;
  late _MockStaffFormBloc staffFormBloc;

  setUp(() {
    staffBloc = _MockStaffBloc();
    staffFormBloc = _MockStaffFormBloc();
    when(() => staffBloc.state).thenReturn(StaffInitial());
    when(() => staffFormBloc.state).thenReturn(const StaffFormInitial());
  });

  tearDown(() {
    staffBloc.close();
    staffFormBloc.close();
  });

  Widget page() => const AddStaffPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StaffBloc>.value(value: staffBloc),
          BlocProvider<StaffFormBloc>.value(value: staffFormBloc),
        ],
        child: child,
      );

  group('AddStaffPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'add_staff_light');
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
      await screenMatchesGolden(tester, 'add_staff_dark');
    });
  });
}
