// Regression test for the 2026-09-21 manual QA finding: ZakatBloc is a
// single instance shared between ZakatCalculatorPage and
// ZakatSettingsPage/ZakatHistoryPage. A bare context.push left the
// calculator page mounted underneath, so tapping "Обновить" (refresh gold
// rate) on the settings page — which dispatches ZakatSettingsRequested and
// leaves the shared bloc in ZakatSettingsLoaded — made the calculator
// render blank on return, since its BlocConsumer only recognizes
// ZakatLoading/ZakatCalculated and falls through to SizedBox.shrink() for
// anything else. Same root-cause class and fix pattern as the Staff/Debts/
// Payroll reload fixes elsewhere in this app: re-request the calculation
// once the pushed route returns.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/zakat_calculation.dart';
import 'package:dukonpro/domain/entities/zakat_settings.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_bloc.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_event.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_state.dart';
import 'package:dukonpro/presentation/pages/zakat/zakat_calculator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class _MockZakatBloc extends MockBloc<ZakatEvent, ZakatState>
    implements ZakatBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late _MockZakatBloc zakatBloc;

  const calculation = ZakatCalculation(
    stockValue: 850,
    receivables: 0,
    payables: 0,
    netAssets: 850,
    nisabAmount: 0,
    zakatDue: 0,
    isAboveNisab: false,
  );

  setUp(() {
    storeBloc = MockStoreBloc();
    zakatBloc = _MockZakatBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => zakatBloc.state)
        .thenReturn(const ZakatCalculated(calculation: calculation));
  });

  tearDown(() {
    zakatBloc.close();
  });

  testWidgets(
      'returning from settings re-requests the calculation so a state the '
      'settings page left the shared bloc in does not blank the calculator',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/zakat',
      routes: [
        GoRoute(
          path: '/zakat',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<StoreBloc>.value(value: storeBloc),
              BlocProvider<ZakatBloc>.value(value: zakatBloc),
            ],
            child: const ZakatCalculatorPage(storeId: 'store-1'),
          ),
        ),
        GoRoute(
          path: '/zakat/settings',
          builder: (context, state) => Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const Text('Settings Stub'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Settings Stub'), findsOneWidget);

    // Simulate the shared bloc having been left in ZakatSettingsLoaded by
    // the settings page's own "Обновить" action.
    when(() => zakatBloc.state).thenReturn(ZakatSettingsLoaded(
      const ZakatSettings(id: 's1', storeId: 'store-1'),
    ));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(ZakatCalculatorPage), findsOneWidget);
    verify(() => zakatBloc.add(const ZakatCalculateRequested(storeId: 'store-1')))
        .called(2); // once from initState, once from the reload-on-return.
  });
}
