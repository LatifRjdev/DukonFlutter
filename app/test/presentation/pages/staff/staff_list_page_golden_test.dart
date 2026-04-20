import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/staff/staff_bloc.dart';
import 'package:dokonpro/presentation/blocs/staff/staff_event.dart';
import 'package:dokonpro/presentation/blocs/staff/staff_state.dart';
import 'package:dokonpro/presentation/pages/staff/staff_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockStaffBloc extends MockBloc<StaffEvent, StaffState>
    implements StaffBloc {}

void main() {
  late _MockStaffBloc staffBloc;

  setUp(() {
    staffBloc = _MockStaffBloc();
    when(() => staffBloc.state).thenReturn(StaffInitial());
  });

  tearDown(() {
    staffBloc.close();
  });

  Widget page() => const StaffListPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => BlocProvider<StaffBloc>.value(
        value: staffBloc,
        child: child,
      );

  group('StaffListPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'staff_list_light');
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
      await screenMatchesGolden(tester, 'staff_list_dark');
    });
  });
}
