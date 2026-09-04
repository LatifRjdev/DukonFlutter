// Regression test for post-plan SPEC.md audit finding (same root cause as
// #1): SupplierListBloc is a single app-wide instance shared with
// SupplierFormPage (pushed from SupplierDetailPage, itself pushed from this
// page). context.push kept SupplierListPage mounted underneath, so its
// initState never re-fired on return, and the bloc's leftover
// SupplierFormLoading/Success/Error state fell through this page's builder
// to the SizedBox.shrink() fallback — a blank screen. The fix re-dispatches
// SupplierListLoadRequested once the pushed detail route returns.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/supplier.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_event.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_state.dart';
import 'package:dukonpro/presentation/pages/supplier/supplier_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class MockSupplierListBloc extends MockBloc<SupplierListEvent, SupplierListState>
    implements SupplierListBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockSupplierListBloc supplierListBloc;

  final supplier = Supplier(
    id: 's1',
    storeId: 'test-store-id',
    name: 'Поставщик 1',
    phone: '+992900000001',
  );

  setUp(() {
    storeBloc = MockStoreBloc();
    supplierListBloc = MockSupplierListBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => supplierListBloc.state).thenReturn(SupplierListLoaded(
      suppliers: [supplier],
      total: 1,
      totalPages: 1,
      currentPage: 1,
    ));
  });

  testWidgets(
    'returning from a supplier detail re-requests the list so the page '
    'does not get stuck on the shared bloc leftover state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/suppliers',
        routes: [
          GoRoute(
            path: '/suppliers',
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider<StoreBloc>.value(value: storeBloc),
                BlocProvider<SupplierListBloc>.value(value: supplierListBloc),
              ],
              child: const SupplierListPage(),
            ),
          ),
          // Stub detail route: simulates returning from SupplierDetailPage
          // (and any SupplierFormPage pushed on top of it) without touching
          // the shared bloc — the bug reproduces because SupplierListPage's
          // initState never re-fires on return, not because of any specific
          // leftover state.
          GoRoute(
            path: '/suppliers/:id',
            builder: (context, state) => Scaffold(
              appBar: AppBar(leading: const BackButton()),
              body: const Text('Supplier Detail'),
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

      verify(() => supplierListBloc.add(const SupplierListLoadRequested(
            storeId: 'test-store-id',
          ))).called(1);

      await tester.tap(find.text('Поставщик 1'));
      await tester.pumpAndSettle();
      expect(find.text('Supplier Detail'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(SupplierListPage), findsOneWidget);
      verify(() => supplierListBloc.add(const SupplierListLoadRequested(
            storeId: 'test-store-id',
          ))).called(1);
    },
  );
}
