// Regression test for the 2026-09-21 manual QA finding: StaffBloc is a
// single app-wide instance shared with StaffDetailPage. context.push kept
// StaffListPage mounted underneath the pushed detail route rather than
// disposing it, so its initState never re-fired on return, and the bloc's
// state by then (StaffDetailLoaded, whatever the detail screen last
// emitted) fell through StaffListPage's builder to a blank screen. The fix
// re-dispatches LoadStaff once the pushed route returns. Same root-cause
// class as the already-fixed post-plan finding №1 for
// Debts/Customers/Suppliers (test/.../debts_overview_reload_test.dart).
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/domain/entities/staff_member.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_bloc.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_event.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_state.dart';
import 'package:dukonpro/presentation/pages/staff/staff_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockStaffBloc extends MockBloc<StaffEvent, StaffState>
    implements StaffBloc {}

void main() {
  late MockStaffBloc staffBloc;

  final member = StaffMember(
    id: 'staff-1',
    storeId: 'test-store-id',
    name: 'Test_Cashier_1',
    phone: '+992900444777',
    role: 'CASHIER',
    createdAt: DateTime(2026, 9, 21),
  );

  final listLoaded = StaffLoaded(staff: [member], total: 1, totalPages: 1);

  setUp(() {
    staffBloc = MockStaffBloc();
    when(() => staffBloc.state).thenReturn(listLoaded);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/staff',
      routes: [
        GoRoute(
          path: '/staff',
          builder: (context, state) => BlocProvider<StaffBloc>.value(
            value: staffBloc,
            child: const StaffListPage(storeId: 'test-store-id'),
          ),
        ),
        // Stub detail route: after the visit, the shared StaffBloc is left
        // in whatever state the real StaffDetailPage would leave it in
        // (simulated here by simply not touching it, since the bug
        // reproduces regardless of the exact left-behind state — the
        // point is StaffListPage's initState never re-fires on return).
        GoRoute(
          path: '/staff/staff-1',
          builder: (context, state) => Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const Text('Staff Detail Stub'),
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
    'returning from a staff detail re-requests the list so the page does '
    'not get stuck blank on the shared bloc leftover state',
    (tester) async {
      await pumpApp(tester);

      // initState fired once already.
      verify(() => staffBloc.add(const LoadStaff(storeId: 'test-store-id')))
          .called(1);

      await tester.tap(find.text('Test_Cashier_1'));
      await tester.pumpAndSettle();
      expect(find.text('Staff Detail Stub'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(StaffListPage), findsOneWidget);
      // Re-requested on return, not just once at initial mount.
      verify(() => staffBloc.add(const LoadStaff(storeId: 'test-store-id')))
          .called(1);
    },
  );
}
