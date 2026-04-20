import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/domain/entities/supplier.dart';
import 'package:dokonpro/injection.dart';
import 'package:dokonpro/presentation/blocs/supplier_detail/supplier_detail_bloc.dart';
import 'package:dokonpro/presentation/blocs/supplier_detail/supplier_detail_event.dart';
import 'package:dokonpro/presentation/blocs/supplier_detail/supplier_detail_state.dart';
import 'package:dokonpro/presentation/pages/supplier/supplier_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockSupplierDetailBloc
    extends MockBloc<SupplierDetailEvent, SupplierDetailState>
    implements SupplierDetailBloc {}

Supplier _fakeSupplier() => const Supplier(
      id: 'test-supplier-id',
      storeId: 'test-store-id',
      name: 'Test Supplier LLC',
      phone: '+992900000001',
      email: 'supplier@test.com',
      address: '1 Test Street',
      debt: 0,
    );

void main() {
  late _MockSupplierDetailBloc supplierDetailBloc;

  setUp(() {
    supplierDetailBloc = _MockSupplierDetailBloc();
    when(() => supplierDetailBloc.state)
        .thenReturn(SupplierDetailLoaded(_fakeSupplier()));
    if (!sl.isRegistered<SupplierDetailBloc>()) {
      sl.registerSingleton<SupplierDetailBloc>(supplierDetailBloc);
    }
  });

  tearDown(() {
    if (sl.isRegistered<SupplierDetailBloc>()) {
      sl.unregister<SupplierDetailBloc>();
    }
  });

  Widget page() => const SupplierDetailPage(
        supplierId: 'test-supplier-id',
        storeId: 'test-store-id',
      );

  group('SupplierDetailPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'supplier_detail_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'supplier_detail_dark');
    });
  });
}
