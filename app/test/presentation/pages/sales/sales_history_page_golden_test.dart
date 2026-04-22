import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/sales/sales_history_bloc.dart';
import 'package:dokonpro/presentation/blocs/sales/sales_history_event.dart';
import 'package:dokonpro/presentation/blocs/sales/sales_history_state.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/sales/sales_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockSalesHistoryBloc
    extends MockBloc<SalesHistoryEvent, SalesHistoryState>
    implements SalesHistoryBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockSalesHistoryBloc salesHistoryBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    salesHistoryBloc = MockSalesHistoryBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => salesHistoryBloc.state).thenReturn(SalesHistoryInitial());
  });

  Widget page() => const SalesHistoryPage();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<SalesHistoryBloc>.value(value: salesHistoryBloc),
        ],
        child: child,
      );

  group('SalesHistoryPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'sales_history_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'sales_history_dark');
    });
  });
}
