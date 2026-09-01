// Regression test for SPEC.md #26: the "Импорт из Excel" button on
// EmptyProductsPage used to call context.push('/products/import') with no
// `extra`, so ImportProductsPage always received storeId: '' — import from
// this empty-state entry point was silently scoped to no store. It must
// instead read the selected store from StoreBloc, matching how
// ProductListPage's equivalent "Импорт из Excel" menu item already does it.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/router/route_names.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/import/import_bloc.dart';
import 'package:dukonpro/presentation/blocs/import/import_event.dart';
import 'package:dukonpro/presentation/blocs/import/import_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/product/empty_products_page.dart';
import 'package:dukonpro/presentation/pages/product/import_products_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class MockImportBloc extends MockBloc<ImportEvent, ImportState>
    implements ImportBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockImportBloc importBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());

    importBloc = MockImportBloc();
    when(() => importBloc.state).thenReturn(const ImportInitial());
    // ImportProductsPage builds its own BlocProvider via sl<ImportBloc>();
    // register the mock so the real page can be reached without touching
    // any real datasources.
    if (sl.isRegistered<ImportBloc>()) sl.unregister<ImportBloc>();
    sl.registerFactory<ImportBloc>(() => importBloc);
  });

  tearDown(() {
    if (sl.isRegistered<ImportBloc>()) sl.unregister<ImportBloc>();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/products/empty',
      routes: [
        GoRoute(
          path: '/products/empty',
          builder: (context, state) => BlocProvider<StoreBloc>.value(
            value: storeBloc,
            child: const EmptyProductsPage(),
          ),
        ),
        // Mirrors the real AppRouter builder for RouteNames.importProducts:
        // reads storeId straight off state.extra.
        GoRoute(
          path: RouteNames.importProducts,
          builder: (context, state) {
            final storeId = state.extra as String? ?? '';
            return ImportProductsPage(storeId: storeId);
          },
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
    'tapping "Импорт из Excel" on the empty-products screen passes the '
    'selected store id from StoreBloc, not an empty string',
    (tester) async {
      await pumpApp(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(EmptyProductsPage)),
      )!;

      await tester.tap(find.text(l10n.importFromExcel));
      await tester.pumpAndSettle();

      expect(find.byType(ImportProductsPage), findsOneWidget);
      final importPage =
          tester.widget<ImportProductsPage>(find.byType(ImportProductsPage));
      expect(importPage.storeId, 'test-store-id');
      expect(importPage.storeId, isNotEmpty);
    },
  );
}
