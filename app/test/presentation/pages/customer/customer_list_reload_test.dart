// Regression test for post-plan SPEC.md audit finding (same root cause as
// #1): CustomerListBloc is a single app-wide instance shared with
// CustomerFormPage (pushed from CustomerDetailPage, itself pushed from this
// page). context.push kept CustomerListPage mounted underneath, so its
// initState never re-fired on return, and the bloc's leftover
// CustomerFormLoading/Success/Error state fell through this page's builder
// to the SizedBox.shrink() fallback — a blank screen. The fix re-dispatches
// CustomerListLoadRequested once the pushed detail route returns.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/customer.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_event.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/customer/customer_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class MockCustomerListBloc extends MockBloc<CustomerListEvent, CustomerListState>
    implements CustomerListBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockCustomerListBloc customerListBloc;

  final customer = Customer(
    id: 'c1',
    storeId: 'test-store-id',
    name: 'Иван',
    phone: '+992900000000',
  );

  setUp(() {
    storeBloc = MockStoreBloc();
    customerListBloc = MockCustomerListBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => customerListBloc.state).thenReturn(CustomerListLoaded(
      customers: [customer],
      total: 1,
      totalPages: 1,
      currentPage: 1,
    ));
  });

  testWidgets(
    'returning from a customer detail re-requests the list so the page '
    'does not get stuck on the shared bloc leftover state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/customers',
        routes: [
          GoRoute(
            path: '/customers',
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider<StoreBloc>.value(value: storeBloc),
                BlocProvider<CustomerListBloc>.value(value: customerListBloc),
              ],
              child: const CustomerListPage(),
            ),
          ),
          // Stub detail route: simulates returning from CustomerDetailPage
          // (and any CustomerFormPage pushed on top of it) without touching
          // the shared bloc — the bug reproduces because CustomerListPage's
          // initState never re-fires on return, not because of any specific
          // leftover state.
          GoRoute(
            path: '/customers/:id',
            builder: (context, state) => Scaffold(
              appBar: AppBar(leading: const BackButton()),
              body: const Text('Customer Detail'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ));
      await tester.pumpAndSettle();

      verify(() => customerListBloc.add(const CustomerListLoadRequested(
            storeId: 'test-store-id',
          ))).called(1);

      await tester.tap(find.text('Иван'));
      await tester.pumpAndSettle();
      expect(find.text('Customer Detail'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerListPage), findsOneWidget);
      verify(() => customerListBloc.add(const CustomerListLoadRequested(
            storeId: 'test-store-id',
          ))).called(1);
    },
  );
}
