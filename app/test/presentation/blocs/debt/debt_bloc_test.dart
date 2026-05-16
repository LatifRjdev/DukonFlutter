import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/core/network/network_info.dart';
import 'package:dukonpro/domain/repositories/debt_repository.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_bloc.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_event.dart';
import 'package:dukonpro/presentation/blocs/debt/debt_state.dart';

class _MockDioClient extends Mock implements DioClient {}
class _MockDebtRepository extends Mock implements DebtRepository {}
class _MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late _MockDioClient dioClient;
  late _MockDebtRepository debtRepository;
  late _MockNetworkInfo networkInfo;

  setUp(() {
    dioClient = _MockDioClient();
    debtRepository = _MockDebtRepository();
    networkInfo = _MockNetworkInfo();
  });

  group('DebtBloc offline payment', () {
    group('DebtPaymentSubmitted (customer payment)', () {
      blocTest<DebtBloc, DebtState>(
        'should emit DebtPaymentQueued when adding customer payment offline',
        setUp: () {
          when(() => networkInfo.isConnected).thenAnswer((_) async => false);
          when(() => debtRepository.addCustomerPayment(
                any(),
                any(),
                any(),
              )).thenAnswer((_) async {});
        },
        build: () => DebtBloc(
          dioClient: dioClient,
          debtRepository: debtRepository,
          networkInfo: networkInfo,
        ),
        act: (bloc) => bloc.add(
          const DebtPaymentSubmitted(
            storeId: 'store-1',
            customerId: 'customer-1',
            saleId: 'sale-1',
            amount: 100.0,
            method: 'CASH',
          ),
        ),
        expect: () => [
          isA<DebtLoading>(),
          isA<DebtPaymentQueued>(),
        ],
        verify: (_) {
          verify(() => debtRepository.addCustomerPayment(
            'store-1',
            'customer-1',
            {
              'saleId': 'sale-1',
              'amount': 100.0,
              'method': 'CASH',
            },
          )).called(1);
        },
      );

      blocTest<DebtBloc, DebtState>(
        'should emit DebtPaymentQueued with notes when offline customer payment includes notes',
        setUp: () {
          when(() => networkInfo.isConnected).thenAnswer((_) async => false);
          when(() => debtRepository.addCustomerPayment(
                any(),
                any(),
                any(),
              )).thenAnswer((_) async {});
        },
        build: () => DebtBloc(
          dioClient: dioClient,
          debtRepository: debtRepository,
          networkInfo: networkInfo,
        ),
        act: (bloc) => bloc.add(
          const DebtPaymentSubmitted(
            storeId: 'store-1',
            customerId: 'customer-1',
            saleId: 'sale-1',
            amount: 50.5,
            method: 'CARD',
            notes: 'Partial payment',
          ),
        ),
        expect: () => [
          isA<DebtLoading>(),
          isA<DebtPaymentQueued>(),
        ],
        verify: (_) {
          verify(() => debtRepository.addCustomerPayment(
            'store-1',
            'customer-1',
            {
              'saleId': 'sale-1',
              'amount': 50.5,
              'method': 'CARD',
              'notes': 'Partial payment',
            },
          )).called(1);
        },
      );
    });

    group('SupplierPaymentSubmitted (supplier payment)', () {
      blocTest<DebtBloc, DebtState>(
        'should emit DebtPaymentQueued when adding supplier payment offline',
        setUp: () {
          when(() => networkInfo.isConnected).thenAnswer((_) async => false);
          when(() => debtRepository.addSupplierPayment(
                any(),
                any(),
                any(),
              )).thenAnswer((_) async {});
        },
        build: () => DebtBloc(
          dioClient: dioClient,
          debtRepository: debtRepository,
          networkInfo: networkInfo,
        ),
        act: (bloc) => bloc.add(
          const SupplierPaymentSubmitted(
            storeId: 'store-1',
            supplierId: 'supplier-1',
            amount: 200.0,
            method: 'CASH',
          ),
        ),
        expect: () => [
          isA<DebtLoading>(),
          isA<DebtPaymentQueued>(),
        ],
        verify: (_) {
          verify(() => debtRepository.addSupplierPayment(
            'store-1',
            'supplier-1',
            {
              'amount': 200.0,
              'method': 'CASH',
            },
          )).called(1);
        },
      );

      blocTest<DebtBloc, DebtState>(
        'should emit DebtPaymentQueued with notes when offline supplier payment includes notes',
        setUp: () {
          when(() => networkInfo.isConnected).thenAnswer((_) async => false);
          when(() => debtRepository.addSupplierPayment(
                any(),
                any(),
                any(),
              )).thenAnswer((_) async {});
        },
        build: () => DebtBloc(
          dioClient: dioClient,
          debtRepository: debtRepository,
          networkInfo: networkInfo,
        ),
        act: (bloc) => bloc.add(
          const SupplierPaymentSubmitted(
            storeId: 'store-1',
            supplierId: 'supplier-1',
            amount: 150.75,
            method: 'TRANSFER',
            notes: 'Invoice #456',
          ),
        ),
        expect: () => [
          isA<DebtLoading>(),
          isA<DebtPaymentQueued>(),
        ],
        verify: (_) {
          verify(() => debtRepository.addSupplierPayment(
            'store-1',
            'supplier-1',
            {
              'amount': 150.75,
              'method': 'TRANSFER',
              'notes': 'Invoice #456',
            },
          )).called(1);
        },
      );
    });
  });
}
