import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/domain/entities/staff_member.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
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
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockStaffBloc extends MockBloc<StaffEvent, StaffState>
    implements StaffBloc {}

class _MockStaffFormBloc extends MockBloc<StaffFormEvent, StaffFormState>
    implements StaffFormBloc {}

class _FakeSubmitStaffForm extends Fake implements StaffFormEvent {}

class _FakeStaffEvent extends Fake implements StaffEvent {}

void main() {
  late _MockStaffBloc staffBloc;
  late _MockStaffFormBloc staffFormBloc;

  setUpAll(() {
    registerFallbackValue(_FakeSubmitStaffForm());
    registerFallbackValue(_FakeStaffEvent());
  });

  setUp(() {
    staffBloc = _MockStaffBloc();
    staffFormBloc = _MockStaffFormBloc();
    when(() => staffBloc.state).thenReturn(StaffInitial());
    when(() => staffFormBloc.state).thenReturn(const StaffFormInitial());
    when(() => staffBloc.close()).thenAnswer((_) async {});
    when(() => staffFormBloc.close()).thenAnswer((_) async {});
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

  // Regression test for the 2026-09-21 manual QA finding: editing a staff
  // member and saving left "Профиль сотрудника" permanently blank on
  // return. Root cause: AddStaffPage and StaffDetailPage share one
  // StaffBloc, and the success listener always dispatched LoadStaff (the
  // list-reload event, emits StaffLoaded) instead of LoadStaffDetail (the
  // detail-reload event, emits StaffDetailLoaded) — StaffDetailPage's
  // BlocBuilder only renders for StaffDetailLoaded, so LoadStaff clobbered
  // it into rendering nothing.
  testWidgets(
      'dispatches LoadStaffDetail (not LoadStaff) when editing succeeds, '
      'so the detail screen being returned to can still render', (tester) async {
    final existing = StaffMember(
      id: 'staff-1',
      storeId: 'test-store-id',
      name: 'Test_Cashier_1',
      phone: '+992900444777',
      role: 'CASHIER',
      createdAt: DateTime(2026, 9, 21),
    );

    // whenListen's stream only starts emitting once something subscribes
    // (i.e. once the widget is pumped), so the initial StaffFormInitial
    // state above is what's seen at mount; queue the success state to
    // arrive right after via a StreamController instead of a fixed list,
    // so it fires only once AddStaffPage's BlocListener is subscribed.
    final controller = StreamController<StaffFormState>();
    whenListen<StaffFormState>(
      staffFormBloc,
      controller.stream,
      initialState: const StaffFormInitial(),
    );
    addTearDown(controller.close);

    final router = GoRouter(
      initialLocation: '/staff/detail',
      routes: [
        GoRoute(
          path: '/staff/detail',
          builder: (context, state) => Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const Text('Staff Detail Stub'),
          ),
        ),
        GoRoute(
          path: '/staff/edit',
          builder: (context, state) => AddStaffPage(
            storeId: 'test-store-id',
            staffMember: existing,
          ),
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<StaffBloc>.value(value: staffBloc),
          BlocProvider<StaffFormBloc>.value(value: staffFormBloc),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/staff/edit');
    await tester.pumpAndSettle();
    expect(find.text('Добавить сотрудника'), findsNothing);

    controller.add(StaffFormSuccess(
      staffMember: existing,
      name: existing.name,
      phone: existing.phone ?? '',
      role: existing.role,
      salary: existing.salary ?? 0,
      commission: existing.commission ?? 0,
      isEditing: true,
      editingId: existing.id,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Staff Detail Stub'), findsOneWidget);
    verify(() => staffBloc.add(any(that: isA<LoadStaffDetail>()))).called(1);
    verifyNever(() => staffBloc.add(any(that: isA<LoadStaff>())));
  });
}
