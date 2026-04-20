import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/l10n/app_localizations.dart';
import 'package:dokonpro/presentation/blocs/debt/debt_bloc.dart';
import 'package:dokonpro/presentation/blocs/debt/debt_event.dart';
import 'package:dokonpro/presentation/blocs/debt/debt_state.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/debt/debts_overview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class MockDebtBloc extends MockBloc<DebtEvent, DebtState> implements DebtBloc {}

Future<void> _pumpPage(
  WidgetTester tester,
  Brightness brightness,
  MockDebtBloc debtBloc,
  MockStoreBloc storeBloc,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<DebtBloc>.value(value: debtBloc),
        ],
        child: const DebtsOverviewPage(storeId: 'test-store-id'),
      ),
    ),
  );
  // Two frames — avoids pumpAndSettle timeout from CircularProgressIndicator
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  late MockStoreBloc storeBloc;
  late MockDebtBloc debtBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    debtBloc = MockDebtBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => debtBloc.state).thenReturn(DebtInitial());
  });

  group('DebtsOverviewPage goldens', () {
    testWidgets('light theme', (tester) async {
      await _pumpPage(tester, Brightness.light, debtBloc, storeBloc);
      tester.takeException();
      await expectLater(
        find.byType(DebtsOverviewPage),
        matchesGoldenFile('goldens/debts_overview_light.png'),
      );
    });

    testWidgets('dark theme', (tester) async {
      await _pumpPage(tester, Brightness.dark, debtBloc, storeBloc);
      tester.takeException();
      await expectLater(
        find.byType(DebtsOverviewPage),
        matchesGoldenFile('goldens/debts_overview_dark.png'),
      );
    });
  });
}
