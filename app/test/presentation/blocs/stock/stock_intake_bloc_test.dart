import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/domain/entities/stock_movement.dart';
import 'package:dukonpro/domain/entities/supplier.dart';
import 'package:dukonpro/domain/repositories/product_repository.dart';
import 'package:dukonpro/domain/repositories/stock_repository.dart';
import 'package:dukonpro/presentation/blocs/stock/stock_intake_bloc.dart';
import 'package:dukonpro/presentation/blocs/stock/stock_intake_event.dart';
import 'package:dukonpro/presentation/blocs/stock/stock_intake_state.dart';

class MockStockRepository extends Mock implements StockRepository {}

class MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late MockStockRepository stockRepository;
  late MockProductRepository productRepository;

  Product mkProduct({
    String id = 'prod-1',
    String storeId = 'store-1',
    String name = 'Bread',
    double sellPrice = 20,
    double? costPrice = 10,
  }) =>
      Product(
        id: id,
        storeId: storeId,
        name: name,
        sellPrice: sellPrice,
        costPrice: costPrice,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  const supplier = Supplier(id: 'sup-1', storeId: 'store-1', name: 'ACME');

  StockMovement mkMovement() => StockMovement(
        id: 'sm-1',
        productId: 'prod-1',
        type: 'PURCHASE',
        quantity: 10,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    stockRepository = MockStockRepository();
    productRepository = MockProductRepository();
  });

  StockIntakeBloc buildBloc() => StockIntakeBloc(
        stockRepository: stockRepository,
        productRepository: productRepository,
      );

  group('StockIntakeBloc', () {
    test('initial state has empty/default values', () {
      final bloc = buildBloc();
      expect(bloc.state.selectedProduct, isNull);
      expect(bloc.state.quantity, 0);
      expect(bloc.state.unitCost, 0);
      expect(bloc.state.supplier, isNull);
      expect(bloc.state.notes, '');
      expect(bloc.state.isSearching, isFalse);
      expect(bloc.state.isSubmitting, isFalse);
      expect(bloc.state.isSuccess, isFalse);
      expect(bloc.state.error, isNull);
      expect(bloc.state.canSubmit, isFalse);
    });

    group('StockIntakeScanBarcode', () {
      blocTest<StockIntakeBloc, StockIntakeState>(
        'on success sets selectedProduct + unitCost from product.costPrice',
        setUp: () {
          when(() => productRepository.getProductByBarcode(any(), any()))
              .thenAnswer((_) async => mkProduct(costPrice: 15));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const StockIntakeScanBarcode(
          storeId: 'store-1',
          barcode: '12345',
        )),
        expect: () => [
          predicate<StockIntakeState>(
              (s) => s.isSearching && s.error == null),
          predicate<StockIntakeState>((s) =>
              !s.isSearching &&
              s.selectedProduct?.id == 'prod-1' &&
              s.unitCost == 15),
        ],
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'defaults unitCost to 0 when product has no costPrice',
        setUp: () {
          when(() => productRepository.getProductByBarcode(any(), any()))
              .thenAnswer((_) async => mkProduct(costPrice: null));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const StockIntakeScanBarcode(
          storeId: 'store-1',
          barcode: '12345',
        )),
        expect: () => [
          predicate<StockIntakeState>((s) => s.isSearching),
          predicate<StockIntakeState>(
              (s) => !s.isSearching && s.unitCost == 0),
        ],
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'on repository failure emits mapped error and clears isSearching',
        setUp: () {
          when(() => productRepository.getProductByBarcode(any(), any()))
              .thenThrow(const NetworkException());
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const StockIntakeScanBarcode(
          storeId: 'store-1',
          barcode: 'not-found',
        )),
        expect: () => [
          predicate<StockIntakeState>((s) => s.isSearching),
          predicate<StockIntakeState>((s) =>
              !s.isSearching &&
              s.error == 'Нет подключения к интернету' &&
              s.selectedProduct == null),
        ],
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'never leaks raw exception text into state.error',
        setUp: () {
          when(() => productRepository.getProductByBarcode(any(), any()))
              .thenThrow(Exception('DioException [bad response]: http://x'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const StockIntakeScanBarcode(
          storeId: 'store-1',
          barcode: 'x',
        )),
        expect: () => [
          predicate<StockIntakeState>((s) => s.isSearching),
          predicate<StockIntakeState>((s) {
            if (s.isSearching) return false;
            final err = s.error ?? '';
            return err.isNotEmpty && !err.contains('DioException');
          }),
        ],
      );
    });

    group('StockIntakeSelectProduct', () {
      blocTest<StockIntakeBloc, StockIntakeState>(
        'sets selectedProduct + unitCost from product.costPrice and clears error',
        build: buildBloc,
        seed: () => const StockIntakeState(error: 'stale error'),
        act: (bloc) =>
            bloc.add(StockIntakeSelectProduct(mkProduct(costPrice: 12))),
        expect: () => [
          predicate<StockIntakeState>((s) =>
              s.selectedProduct?.id == 'prod-1' &&
              s.unitCost == 12 &&
              s.error == null),
        ],
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'defaults unitCost to 0 when selected product has no costPrice',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(StockIntakeSelectProduct(mkProduct(costPrice: null))),
        expect: () => [
          predicate<StockIntakeState>((s) => s.unitCost == 0),
        ],
      );
    });

    group('StockIntakeSetQuantity', () {
      blocTest<StockIntakeBloc, StockIntakeState>(
        'updates quantity and clears error',
        build: buildBloc,
        seed: () => const StockIntakeState(error: 'stale error'),
        act: (bloc) => bloc.add(const StockIntakeSetQuantity(7)),
        expect: () => [
          predicate<StockIntakeState>(
              (s) => s.quantity == 7 && s.error == null),
        ],
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'allows zero and negative quantity to be set (guard is enforced at submit)',
        build: buildBloc,
        act: (bloc) => bloc.add(const StockIntakeSetQuantity(-3)),
        expect: () => [
          predicate<StockIntakeState>((s) => s.quantity == -3),
        ],
        verify: (bloc) {
          expect(bloc.state.canSubmit, isFalse);
        },
      );
    });

    group('StockIntakeSetUnitCost', () {
      blocTest<StockIntakeBloc, StockIntakeState>(
        'updates unitCost and clears error',
        build: buildBloc,
        seed: () => const StockIntakeState(error: 'stale error'),
        act: (bloc) => bloc.add(const StockIntakeSetUnitCost(9.5)),
        expect: () => [
          predicate<StockIntakeState>(
              (s) => s.unitCost == 9.5 && s.error == null),
        ],
      );
    });

    group('StockIntakeSelectSupplier', () {
      blocTest<StockIntakeBloc, StockIntakeState>(
        'sets supplier when non-null',
        build: buildBloc,
        act: (bloc) => bloc.add(const StockIntakeSelectSupplier(supplier)),
        expect: () => [
          predicate<StockIntakeState>((s) => s.supplier?.id == 'sup-1'),
        ],
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'clears supplier when null is passed',
        build: buildBloc,
        seed: () => const StockIntakeState(supplier: supplier),
        act: (bloc) => bloc.add(const StockIntakeSelectSupplier(null)),
        expect: () => [
          predicate<StockIntakeState>((s) => s.supplier == null),
        ],
      );
    });

    group('StockIntakeSetNotes', () {
      blocTest<StockIntakeBloc, StockIntakeState>(
        'updates notes',
        build: buildBloc,
        act: (bloc) => bloc.add(const StockIntakeSetNotes('fragile items')),
        expect: () => [
          predicate<StockIntakeState>((s) => s.notes == 'fragile items'),
        ],
      );
    });

    group('StockIntakeSubmit', () {
      blocTest<StockIntakeBloc, StockIntakeState>(
        'does nothing when canSubmit is false (no product selected)',
        build: buildBloc,
        seed: () => const StockIntakeState(quantity: 5, unitCost: 10),
        act: (bloc) =>
            bloc.add(const StockIntakeSubmit(storeId: 'store-1')),
        expect: () => [],
        verify: (_) {
          verifyNever(
              () => stockRepository.createStockMovement(any(), any(), any()));
        },
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'does nothing when quantity is zero (guard)',
        build: buildBloc,
        seed: () => StockIntakeState(
          selectedProduct: mkProduct(),
          quantity: 0,
          unitCost: 10,
        ),
        act: (bloc) =>
            bloc.add(const StockIntakeSubmit(storeId: 'store-1')),
        expect: () => [],
        verify: (_) {
          verifyNever(
              () => stockRepository.createStockMovement(any(), any(), any()));
        },
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'does nothing when quantity is negative (guard)',
        build: buildBloc,
        seed: () => StockIntakeState(
          selectedProduct: mkProduct(),
          quantity: -1,
          unitCost: 10,
        ),
        act: (bloc) =>
            bloc.add(const StockIntakeSubmit(storeId: 'store-1')),
        expect: () => [],
        verify: (_) {
          verifyNever(
              () => stockRepository.createStockMovement(any(), any(), any()));
        },
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'does nothing when unitCost is zero (guard)',
        build: buildBloc,
        seed: () => StockIntakeState(
          selectedProduct: mkProduct(),
          quantity: 5,
          unitCost: 0,
        ),
        act: (bloc) =>
            bloc.add(const StockIntakeSubmit(storeId: 'store-1')),
        expect: () => [],
        verify: (_) {
          verifyNever(
              () => stockRepository.createStockMovement(any(), any(), any()));
        },
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'on success emits isSubmitting=true then isSuccess=true',
        setUp: () {
          when(() => stockRepository.createStockMovement(any(), any(), any()))
              .thenAnswer((_) async => mkMovement());
        },
        build: buildBloc,
        seed: () => StockIntakeState(
          selectedProduct: mkProduct(),
          quantity: 10,
          unitCost: 5,
          supplier: supplier,
          notes: 'careful',
        ),
        act: (bloc) =>
            bloc.add(const StockIntakeSubmit(storeId: 'store-1')),
        expect: () => [
          predicate<StockIntakeState>(
              (s) => s.isSubmitting && s.error == null),
          predicate<StockIntakeState>(
              (s) => !s.isSubmitting && s.isSuccess),
        ],
        verify: (_) {
          final captured = verify(() => stockRepository.createStockMovement(
                captureAny(),
                captureAny(),
                captureAny(),
              )).captured;
          expect(captured[0], 'store-1');
          expect(captured[1], 'prod-1');
          final payload = captured[2] as Map<String, dynamic>;
          expect(payload['type'], 'PURCHASE');
          expect(payload['quantity'], 10);
          expect(payload['unitCost'], 5);
          expect(payload['totalCost'], 50);
          expect(payload['supplierId'], 'sup-1');
          expect(payload['notes'], 'careful');
        },
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'omits supplierId and notes from payload when absent',
        setUp: () {
          when(() => stockRepository.createStockMovement(any(), any(), any()))
              .thenAnswer((_) async => mkMovement());
        },
        build: buildBloc,
        seed: () => StockIntakeState(
          selectedProduct: mkProduct(),
          quantity: 3,
          unitCost: 4,
        ),
        act: (bloc) =>
            bloc.add(const StockIntakeSubmit(storeId: 'store-1')),
        expect: () => [
          predicate<StockIntakeState>((s) => s.isSubmitting),
          predicate<StockIntakeState>((s) => s.isSuccess),
        ],
        verify: (_) {
          final captured = verify(() => stockRepository.createStockMovement(
                any(),
                any(),
                captureAny(),
              )).captured;
          final payload = captured.single as Map<String, dynamic>;
          expect(payload.containsKey('supplierId'), isFalse);
          expect(payload.containsKey('notes'), isFalse);
        },
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'on NetworkException emits isSubmitting=false + offline message',
        setUp: () {
          when(() => stockRepository.createStockMovement(any(), any(), any()))
              .thenThrow(const NetworkException());
        },
        build: buildBloc,
        seed: () => StockIntakeState(
          selectedProduct: mkProduct(),
          quantity: 10,
          unitCost: 5,
        ),
        act: (bloc) =>
            bloc.add(const StockIntakeSubmit(storeId: 'store-1')),
        expect: () => [
          predicate<StockIntakeState>((s) => s.isSubmitting),
          predicate<StockIntakeState>((s) =>
              !s.isSubmitting &&
              s.error == 'Нет подключения к интернету' &&
              !s.isSuccess),
        ],
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'on ServerException(400) emits validation error message',
        setUp: () {
          when(() => stockRepository.createStockMovement(any(), any(), any()))
              .thenThrow(const ServerException('bad', statusCode: 400));
        },
        build: buildBloc,
        seed: () => StockIntakeState(
          selectedProduct: mkProduct(),
          quantity: 10,
          unitCost: 5,
        ),
        act: (bloc) =>
            bloc.add(const StockIntakeSubmit(storeId: 'store-1')),
        expect: () => [
          predicate<StockIntakeState>((s) => s.isSubmitting),
          predicate<StockIntakeState>(
              (s) => !s.isSubmitting && s.error == 'Некорректные данные'),
        ],
      );

      blocTest<StockIntakeBloc, StockIntakeState>(
        'never leaks raw exception text into state.error on submit failure',
        setUp: () {
          when(() => stockRepository.createStockMovement(any(), any(), any()))
              .thenThrow(Exception('DioException [bad response]: http://x'));
        },
        build: buildBloc,
        seed: () => StockIntakeState(
          selectedProduct: mkProduct(),
          quantity: 10,
          unitCost: 5,
        ),
        act: (bloc) =>
            bloc.add(const StockIntakeSubmit(storeId: 'store-1')),
        expect: () => [
          predicate<StockIntakeState>((s) => s.isSubmitting),
          predicate<StockIntakeState>((s) {
            if (s.isSubmitting) return false;
            final err = s.error ?? '';
            return err.isNotEmpty && !err.contains('DioException');
          }),
        ],
      );
    });

    group('StockIntakeReset', () {
      blocTest<StockIntakeBloc, StockIntakeState>(
        'resets to default state regardless of prior modifications',
        build: buildBloc,
        seed: () => StockIntakeState(
          selectedProduct: mkProduct(),
          quantity: 10,
          unitCost: 5,
          supplier: supplier,
          notes: 'careful',
          isSuccess: true,
          error: 'boom',
        ),
        act: (bloc) => bloc.add(StockIntakeReset()),
        expect: () => [const StockIntakeState()],
      );
    });
  });
}
