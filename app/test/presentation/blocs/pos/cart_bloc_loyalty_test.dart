import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dukonpro/domain/entities/loyalty_transaction.dart';
import 'package:dukonpro/domain/repositories/loyalty_repository.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_bloc.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_event.dart';
import 'package:dukonpro/presentation/blocs/pos/cart_state.dart';

class MockLoyaltyRepository extends Mock implements LoyaltyRepository {}

void main() {
  late MockLoyaltyRepository loyaltyRepo;

  setUp(() {
    loyaltyRepo = MockLoyaltyRepository();
    when(() => loyaltyRepo.getCustomerBalance(any(), any())).thenAnswer(
      (_) async => (points: 200, transactions: <LoyaltyTransaction>[]),
    );
    when(() => loyaltyRepo.getSettings(any())).thenAnswer(
      (_) async => <String, dynamic>{'pointValue': 0.01},
    );
  });

  group('loyalty balance loading', () {
    blocTest<CartBloc, CartState>(
      'should load loyalty balance when customer is selected',
      build: () => CartBloc(loyaltyRepository: loyaltyRepo),
      act: (bloc) => bloc.add(
        const CartCustomerSelected(customerId: 'c1', customerName: 'Ali', storeId: 's1'),
      ),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<CartState>()
            .having((s) => s.customerId, 'customerId', 'c1')
            .having((s) => s.redemptionPoints, 'redemption reset', 0),
        isA<CartState>()
            .having((s) => s.customerLoyaltyPoints, 'points', 200)
            .having((s) => s.loyaltyPointValue, 'pointValue', 0.01),
      ],
    );

    blocTest<CartBloc, CartState>(
      'should clear loyalty when customer is removed',
      build: () => CartBloc(loyaltyRepository: loyaltyRepo),
      seed: () => const CartState(
        customerId: 'c1',
        customerName: 'Ali',
        customerLoyaltyPoints: 200,
        loyaltyPointValue: 0.01,
        redemptionPoints: 50,
      ),
      act: (bloc) => bloc.add(const CartCustomerSelected(customerId: null)),
      expect: () => [
        isA<CartState>()
            .having((s) => s.customerId, 'customerId', null)
            .having((s) => s.customerLoyaltyPoints, 'points', 0)
            .having((s) => s.redemptionPoints, 'redemption', 0),
      ],
    );

    blocTest<CartBloc, CartState>(
      'should silently ignore loyalty errors and keep cart usable',
      build: () {
        when(() => loyaltyRepo.getCustomerBalance(any(), any()))
            .thenThrow(Exception('network'));
        when(() => loyaltyRepo.getSettings(any()))
            .thenThrow(Exception('network'));
        return CartBloc(loyaltyRepository: loyaltyRepo);
      },
      act: (bloc) => bloc.add(
        const CartCustomerSelected(customerId: 'c1', customerName: 'Ali', storeId: 's1'),
      ),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<CartState>()
            .having((s) => s.customerId, 'customerId', 'c1')
            .having((s) => s.customerLoyaltyPoints, 'points still 0', 0),
      ],
    );
  });

  group('redemption', () {
    blocTest<CartBloc, CartState>(
      'should cap redemption at floor(total / pointValue)',
      build: () => CartBloc(loyaltyRepository: loyaltyRepo),
      seed: () => const CartState(
        customerLoyaltyPoints: 5000,
        loyaltyPointValue: 0.01,
        redemptionPoints: 10,
      ),
      act: (bloc) => bloc.add(const RedemptionPointsChanged(99999)),
      // subtotal = 0, maxByTotal = 0, cap = 0 → changed from 10 to 0
      expect: () => [
        isA<CartState>().having((s) => s.redemptionPoints, 'capped at 0', 0),
      ],
    );

    blocTest<CartBloc, CartState>(
      'should apply requested redemption within cart total and balance',
      build: () => CartBloc(loyaltyRepository: loyaltyRepo),
      seed: () => CartState(
        items: [
          CartItem(
            productId: 'p1',
            productName: 'Widget',
            unitPrice: 500,
            quantity: 1,
            unit: 'PCS',
          ),
        ],
        customerLoyaltyPoints: 5000,
        loyaltyPointValue: 0.01,
      ),
      act: (bloc) => bloc.add(const RedemptionPointsChanged(100)),
      // total=500, pointValue=0.01, maxByTotal=50000 → cap=min(5000,50000)=5000
      // requested 100 < 5000 → accepted as-is
      expect: () => [
        isA<CartState>()
            .having((s) => s.redemptionPoints, 'points', 100)
            .having((s) => s.loyaltyRedemptionValue, 'redemption value', 1.0),
      ],
    );

    blocTest<CartBloc, CartState>(
      'should reflect redemption in total',
      build: () => CartBloc(loyaltyRepository: loyaltyRepo),
      seed: () => CartState(
        items: [
          CartItem(
            productId: 'p1',
            productName: 'Widget',
            unitPrice: 200,
            quantity: 1,
            unit: 'PCS',
          ),
        ],
        customerLoyaltyPoints: 1000,
        loyaltyPointValue: 0.5,
        redemptionPoints: 50,
      ),
      act: (bloc) => bloc.add(const RedemptionPointsChanged(100)),
      // max by balance = 1000, maxByTotal = floor(200/0.5)=400
      // cap = min(1000,400) = 400 → 100 accepted, total = 200 - 50 = 150
      expect: () => [
        isA<CartState>()
            .having((s) => s.total, 'total', 150.0),
      ],
    );
  });
}
