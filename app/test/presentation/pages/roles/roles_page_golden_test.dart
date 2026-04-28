import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/roles/roles_bloc.dart';
import 'package:dukonpro/presentation/blocs/roles/roles_event.dart';
import 'package:dukonpro/presentation/blocs/roles/roles_state.dart';
import 'package:dukonpro/presentation/pages/roles/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockRolesBloc extends MockBloc<RolesEvent, RolesState>
    implements RolesBloc {}

void main() {
  late _MockRolesBloc rolesBloc;

  setUp(() {
    rolesBloc = _MockRolesBloc();
    when(() => rolesBloc.state).thenReturn(RolesInitial());
  });

  tearDown(() {
    rolesBloc.close();
  });

  Widget page() => const RolesPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => BlocProvider<RolesBloc>.value(
        value: rolesBloc,
        child: child,
      );

  group('RolesPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'roles_light');
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
      await screenMatchesGolden(tester, 'roles_dark');
    });
  });
}
