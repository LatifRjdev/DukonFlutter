import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_event.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_state.dart';
import 'package:dukonpro/presentation/pages/supplier/supplier_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockSupplierListBloc
    extends MockBloc<SupplierListEvent, SupplierListState>
    implements SupplierListBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockSupplierListBloc supplierListBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    supplierListBloc = MockSupplierListBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => supplierListBloc.state).thenReturn(SupplierListInitial());
  });

  Widget page() => const SupplierListPage();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<SupplierListBloc>.value(value: supplierListBloc),
        ],
        child: child,
      );

  group('SupplierListPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'supplier_list_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'supplier_list_dark');
    });
  });
}
