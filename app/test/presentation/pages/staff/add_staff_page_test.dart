import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_bloc.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_event.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_state.dart';
import 'package:dukonpro/presentation/blocs/staff_form/staff_form_bloc.dart';
import 'package:dukonpro/presentation/blocs/staff_form/staff_form_event.dart';
import 'package:dukonpro/presentation/blocs/staff_form/staff_form_state.dart';
import 'package:dukonpro/presentation/pages/staff/add_staff_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockStaffBloc extends MockBloc<StaffEvent, StaffState>
    implements StaffBloc {}

class _MockStaffFormBloc extends MockBloc<StaffFormEvent, StaffFormState>
    implements StaffFormBloc {}

class _FakeSubmitStaffForm extends Fake implements StaffFormEvent {}

void main() {
  late _MockStaffBloc staffBloc;
  late _MockStaffFormBloc staffFormBloc;

  setUpAll(() {
    registerFallbackValue(_FakeSubmitStaffForm());
  });

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

  // Regression test for the 2026-09-21 manual QA finding: the "Телефон"
  // field on "Добавить сотрудника" had no validator and no required-field
  // marker, but the backend's CreateStaffDto requires `phone`
  // (@IsString(), not @IsOptional()) — so submitting a name-only form 400'd
  // with the generic "Некорректные данные" instead of a specific inline
  // error. Fixed by validating phone the same way login/register do.
  testWidgets(
      'blocks submission when phone is left empty, without dispatching '
      'SubmitStaffForm', (tester) async {
    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
      wrap: wrapWithBlocs,
      size: const Size(412, 900),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Имя сотрудника'),
      'Test_Cashier_1',
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Введите номер телефона'), findsOneWidget);
    verifyNever(() => staffFormBloc.add(any(that: isA<SubmitStaffForm>())));
  });

  testWidgets('submits when name and phone are both valid', (tester) async {
    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
      wrap: wrapWithBlocs,
      size: const Size(412, 900),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Имя сотрудника'),
      'Test_Cashier_1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Телефон *'),
      '+992900333555',
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    verify(() => staffFormBloc.add(any(that: isA<SubmitStaffForm>())))
        .called(1);
  });
}
