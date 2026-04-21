import 'package:dokonpro/core/services/receipt_share_service.dart';
import 'package:dokonpro/core/services/thermal_printer_service.dart';
import 'package:dokonpro/domain/entities/sale.dart';
import 'package:dokonpro/injection.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/pages/pos/receipt_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

// ── Fakes for sl<ThermalPrinterService> and sl<ReceiptShareService> ───────────

class _FakeThermalPrinterService extends Fake implements ThermalPrinterService {
  @override
  bool get isConnected => false;
}

class _FakeReceiptShareService extends Fake implements ReceiptShareService {
  @override
  Future<void> shareReceipt({
    required Sale sale,
    required String storeName,
    String? storeAddress,
    String? storePhone,
  }) async {}
}

// ── Deterministic Sale fixture ─────────────────────────────────────────────────

Sale _fakeSale() => Sale(
      id: 'sale-1',
      storeId: 'test-store-id',
      receiptNo: 'RCP-0001',
      subtotal: 1000,
      total: 1000,
      paymentType: 'CASH',
      paidAmount: 1000,
      change: 0,
      createdAt: DateTime(2024, 1, 1),
    );

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  late MockStoreBloc storeBloc;

  setUp(() {
    if (!sl.isRegistered<ThermalPrinterService>()) {
      sl.registerSingleton<ThermalPrinterService>(_FakeThermalPrinterService());
    }
    if (!sl.isRegistered<ReceiptShareService>()) {
      sl.registerSingleton<ReceiptShareService>(_FakeReceiptShareService());
    }

    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
  });

  tearDown(() {
    if (sl.isRegistered<ThermalPrinterService>()) {
      sl.unregister<ThermalPrinterService>();
    }
    if (sl.isRegistered<ReceiptShareService>()) {
      sl.unregister<ReceiptShareService>();
    }
  });

  Widget page() => ReceiptPreviewPage(sale: _fakeSale());

  Widget wrapWithBlocs(Widget child) => BlocProvider<StoreBloc>.value(
        value: storeBloc,
        child: child,
      );

  group('ReceiptPreviewPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'receipt_preview_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'receipt_preview_dark');
    });
  });
}
