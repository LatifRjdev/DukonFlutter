import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dokonpro/core/errors/exceptions.dart';
import 'package:dokonpro/domain/entities/sale.dart';
import 'package:dokonpro/domain/repositories/sale_repository.dart';
import 'package:dokonpro/presentation/blocs/pos/cart_state.dart';
import 'package:dokonpro/presentation/blocs/pos/checkout_bloc.dart';
import 'package:dokonpro/presentation/blocs/pos/checkout_event.dart';
import 'package:dokonpro/presentation/blocs/pos/checkout_state.dart';

class MockSaleRepository extends Mock implements SaleRepository {}

class FakeSale extends Fake implements Sale {
  @override
  final String id;
  FakeSale(this.id);
}

void main() {
  late MockSaleRepository repository;

  const cartItem = CartItem(
    productId: 'p1',
    productName: 'Bread',
    unitPrice: 10,
    costPrice: 5,
    quantity: 2,
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = MockSaleRepository();
  });

  group('CheckoutBloc', () {
    test('initial state has empty cart + default CASH payment', () {
      final bloc = CheckoutBloc(saleRepository: repository);
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.total, 0);
      expect(bloc.state.paymentMethod, 'CASH');
      expect(bloc.state.isProcessing, isFalse);
    });

    group('CheckoutInitiated', () {
      blocTest<CheckoutBloc, CheckoutState>(
        'seeds cart/totals and defaults paidAmount to total',
        build: () => CheckoutBloc(saleRepository: repository),
        act: (bloc) => bloc.add(const CheckoutInitiated(
          items: [cartItem],
          subtotal: 20,
          discount: 0,
          total: 20,
        )),
        expect: () => [
          predicate<CheckoutState>((s) =>
              s.items.length == 1 &&
              s.subtotal == 20 &&
              s.total == 20 &&
              s.paidAmount == 20),
        ],
      );
    });

    group('CheckoutDiscountApplied', () {
      blocTest<CheckoutBloc, CheckoutState>(
        'FIXED discount reduces total by the discount value',
        build: () => CheckoutBloc(saleRepository: repository),
        seed: () => const CheckoutState(
          items: [cartItem],
          subtotal: 20,
          total: 20,
          paidAmount: 20,
        ),
        act: (bloc) => bloc.add(const CheckoutDiscountApplied(
          discount: 5,
          discountType: 'FIXED',
        )),
        expect: () => [
          predicate<CheckoutState>((s) =>
              s.discount == 5 &&
              s.total == 15 &&
              s.paidAmount == 15 &&
              s.discountType == 'FIXED'),
        ],
      );

      blocTest<CheckoutBloc, CheckoutState>(
        'PERCENTAGE discount reduces total by subtotal * pct / 100',
        build: () => CheckoutBloc(saleRepository: repository),
        seed: () => const CheckoutState(
          items: [cartItem],
          subtotal: 200,
          total: 200,
          paidAmount: 200,
        ),
        act: (bloc) => bloc.add(const CheckoutDiscountApplied(
          discount: 10, // 10%
          discountType: 'PERCENTAGE',
        )),
        expect: () => [
          predicate<CheckoutState>((s) =>
              s.total == 180 && s.paidAmount == 180),
        ],
      );

      blocTest<CheckoutBloc, CheckoutState>(
        'discount greater than subtotal clamps total to 0 (never negative)',
        build: () => CheckoutBloc(saleRepository: repository),
        seed: () => const CheckoutState(
          items: [cartItem],
          subtotal: 20,
          total: 20,
          paidAmount: 20,
        ),
        act: (bloc) => bloc.add(const CheckoutDiscountApplied(
          discount: 100,
          discountType: 'FIXED',
        )),
        expect: () => [
          predicate<CheckoutState>((s) => s.total == 0 && s.paidAmount == 0),
        ],
      );
    });

    group('CheckoutPaidAmountChanged / change computation', () {
      test('change is the positive difference between paidAmount and total', () {
        const state = CheckoutState(
          items: [cartItem],
          subtotal: 20,
          total: 20,
          paidAmount: 50,
        );
        expect(state.change, 30);
      });

      test('change is zero when paidAmount <= total (no tip)', () {
        const state = CheckoutState(
          items: [cartItem],
          subtotal: 20,
          total: 20,
          paidAmount: 15,
        );
        expect(state.change, 0);
      });
    });

    group('CheckoutProcessPayment', () {
      blocTest<CheckoutBloc, CheckoutState>(
        'on success emits isProcessing=true then saleResult',
        setUp: () {
          when(() => repository.createSale(any(), any()))
              .thenAnswer((_) async => FakeSale('sale-1'));
        },
        build: () => CheckoutBloc(saleRepository: repository),
        seed: () => const CheckoutState(
          items: [cartItem],
          subtotal: 20,
          total: 20,
          paidAmount: 20,
        ),
        act: (bloc) =>
            bloc.add(const CheckoutProcessPayment(storeId: 'store-1')),
        expect: () => [
          predicate<CheckoutState>((s) => s.isProcessing && s.error == null),
          predicate<CheckoutState>((s) =>
              !s.isProcessing &&
              s.saleResult != null &&
              s.error == null),
        ],
        verify: (_) {
          final captured = verify(
            () => repository.createSale(captureAny(), captureAny()),
          ).captured;
          expect(captured[0], 'store-1');
          final payload = captured[1] as Map<String, dynamic>;
          expect(payload['paymentType'], 'CASH');
          expect(payload['paidAmount'], 20);
          // Money path: items must carry productId + quantity, no raw prices
          // (server computes total from product catalog).
          final items = payload['items'] as List<dynamic>;
          expect(items.length, 1);
          final first = items.first as Map<String, dynamic>;
          expect(first['productId'], 'p1');
          expect(first['quantity'], 2);
        },
      );

      blocTest<CheckoutBloc, CheckoutState>(
        'on NetworkException emits isProcessing=false + offline message',
        setUp: () {
          when(() => repository.createSale(any(), any()))
              .thenThrow(const NetworkException());
        },
        build: () => CheckoutBloc(saleRepository: repository),
        seed: () => const CheckoutState(
          items: [cartItem],
          subtotal: 20,
          total: 20,
          paidAmount: 20,
        ),
        act: (bloc) =>
            bloc.add(const CheckoutProcessPayment(storeId: 'store-1')),
        expect: () => [
          predicate<CheckoutState>((s) => s.isProcessing),
          predicate<CheckoutState>((s) =>
              !s.isProcessing &&
              s.error == 'Нет подключения к интернету' &&
              s.saleResult == null),
        ],
      );

      blocTest<CheckoutBloc, CheckoutState>(
        'never leaks raw exception text into state.error (FE-P1-002 regression)',
        setUp: () {
          when(() => repository.createSale(any(), any())).thenThrow(
            Exception('DioException [bad response]: http://10.0.2.2:4455/sales'),
          );
        },
        build: () => CheckoutBloc(saleRepository: repository),
        seed: () => const CheckoutState(
          items: [cartItem],
          subtotal: 20,
          total: 20,
          paidAmount: 20,
        ),
        act: (bloc) =>
            bloc.add(const CheckoutProcessPayment(storeId: 'store-1')),
        expect: () => [
          predicate<CheckoutState>((s) => s.isProcessing),
          predicate<CheckoutState>((s) {
            if (s.isProcessing) return false;
            final err = s.error ?? '';
            return !err.contains('10.0.2.2') &&
                !err.contains('DioException') &&
                err.isNotEmpty;
          }, 'error set but no leaky internal text'),
        ],
      );
    });
  });
}
