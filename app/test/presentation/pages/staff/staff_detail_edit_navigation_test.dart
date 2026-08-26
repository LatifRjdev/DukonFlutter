// Regression test for SPEC.md #5: the edit icon on StaffDetailPage used to
// push '/edit-staff/:storeId/:staffId', a route that was never registered in
// AppRouter (a dead route -> silent no-op tap). It must instead reuse the
// existing, working AddStaffPage in edit mode via '/staff/add'.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/router/route_names.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/domain/entities/staff_member.dart';
import 'package:dukonpro/domain/repositories/staff_repository.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_bloc.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_event.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_state.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_bloc.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_event.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_state.dart';
import 'package:dukonpro/presentation/blocs/staff_form/staff_form_bloc.dart';
import 'package:dukonpro/presentation/pages/staff/add_staff_page.dart';
import 'package:dukonpro/presentation/pages/staff/staff_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockStaffBloc extends MockBloc<StaffEvent, StaffState>
    implements StaffBloc {}

class _MockShiftBloc extends MockBloc<ShiftEvent, ShiftState>
    implements ShiftBloc {}

class MockStaffRepository extends Mock implements StaffRepository {}

void main() {
  late _MockStaffBloc staffBloc;
  late _MockShiftBloc shiftBloc;
  late MockStaffRepository repository;

  final member = StaffMember(
    id: 'staff-1',
    storeId: 'store-1',
    name: 'Ali Valiev',
    phone: '+992900000000',
    role: 'CASHIER',
    salary: 1000,
    commission: 5,
    createdAt: DateTime(2026, 4, 11),
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    staffBloc = _MockStaffBloc();
    shiftBloc = _MockShiftBloc();
    repository = MockStaffRepository();
    when(() => staffBloc.state).thenReturn(StaffDetailLoaded(member));
    when(() => shiftBloc.state).thenReturn(ShiftInitial());
    when(() => repository.updateStaff(any(), any(), any()))
        .thenAnswer((_) async => member);
  });

  tearDown(() {
    staffBloc.close();
    shiftBloc.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/staff/${member.id}',
      routes: [
        // Mirrors the real AppRouter route order: the literal '/staff/add'
        // route must be registered before the dynamic '/staff/:id' route, or
        // GoRouter matches '/staff/add' as '/staff/:id' with id='add'.
        // Also mirrors the real AppRouter builder for RouteNames.addStaff:
        // unpacks a Map extra into storeId + staffMember for edit mode.
        GoRoute(
          path: RouteNames.addStaff,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final storeId = extra['storeId'] as String? ?? '';
            final staffMember = extra['staffMember'] as StaffMember?;
            return MultiBlocProvider(
              providers: [
                BlocProvider<StaffBloc>.value(value: staffBloc),
                BlocProvider<StaffFormBloc>(
                  create: (_) => StaffFormBloc(staffRepository: repository),
                ),
              ],
              child: AddStaffPage(storeId: storeId, staffMember: staffMember),
            );
          },
        ),
        GoRoute(
          path: '/staff/:id',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<StaffBloc>.value(value: staffBloc),
              BlocProvider<ShiftBloc>.value(value: shiftBloc),
            ],
            child: StaffDetailPage(
              storeId: 'store-1',
              staffId: state.pathParameters['id']!,
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tapping the edit icon opens AddStaffPage pre-filled in edit mode for '
    'the loaded staff member',
    (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.edit), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Landed on the real, working AddStaffPage rather than the dead
      // '/edit-staff/...' route (which would have left the tap a no-op).
      expect(find.byType(AddStaffPage), findsOneWidget);

      final l10n =
          AppLocalizations.of(tester.element(find.byType(AddStaffPage)))!;
      expect(find.text(l10n.editEmployee), findsOneWidget);
      expect(find.text(member.name), findsOneWidget);
      expect(find.text(member.phone!), findsOneWidget);

      await tester.tap(find.text(l10n.save));
      await tester.pumpAndSettle();

      verify(
        () => repository.updateStaff('store-1', 'staff-1', any()),
      ).called(1);
      verifyNever(() => repository.createStaff(any(), any()));
    },
  );
}
