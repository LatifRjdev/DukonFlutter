import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_bloc.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_event.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_state.dart';

class MockDioClient extends Mock implements DioClient {}

void main() {
  late MockDioClient dioClient;

  setUp(() {
    dioClient = MockDioClient();
  });

  Response<dynamic> resp(dynamic body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  Map<String, dynamic> fullCustomerJson() => {
        'id': 'c1',
        'storeId': 'store-1',
        'name': 'Ali',
        'phone': '+992900000000',
        'email': 'ali@example.com',
        'notes': 'VIP',
        'loyaltyPoints': 50,
        'totalSpent': 1000,
        'debt': 200,
        'sales': [
          {'id': 'sale-1', 'total': 100},
          {'id': 'sale-2', 'total': 200},
        ],
      };

  group('CustomerDetailBloc', () {
    test('initial state is CustomerDetailInitial', () {
      final bloc = CustomerDetailBloc(dioClient: dioClient);
      expect(bloc.state, isA<CustomerDetailInitial>());
    });

    group('CustomerDetailRequested', () {
      blocTest<CustomerDetailBloc, CustomerDetailState>(
        'emits [Loading, Loaded] with mapped customer + recentSales on success',
        setUp: () {
          when(() => dioClient.get<dynamic>(any()))
              .thenAnswer((_) async => resp(fullCustomerJson()));
        },
        build: () => CustomerDetailBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const CustomerDetailRequested(
          storeId: 'store-1',
          customerId: 'c1',
        )),
        expect: () => [
          isA<CustomerDetailLoading>(),
          predicate<CustomerDetailState>((s) =>
              s is CustomerDetailLoaded &&
              s.customer.id == 'c1' &&
              s.customer.name == 'Ali' &&
              s.customer.loyaltyPoints == 50 &&
              s.customer.totalSpent == 1000 &&
              s.customer.debt == 200 &&
              s.recentSales.length == 2),
        ],
      );

      blocTest<CustomerDetailBloc, CustomerDetailState>(
        'defaults recentSales to empty list when sales field is absent',
        setUp: () {
          when(() => dioClient.get<dynamic>(any())).thenAnswer((_) async => resp({
                'id': 'c1',
                'storeId': 'store-1',
                'name': 'Ali',
              }));
        },
        build: () => CustomerDetailBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const CustomerDetailRequested(
          storeId: 'store-1',
          customerId: 'c1',
        )),
        expect: () => [
          isA<CustomerDetailLoading>(),
          predicate<CustomerDetailState>((s) =>
              s is CustomerDetailLoaded && s.recentSales.isEmpty),
        ],
      );

      blocTest<CustomerDetailBloc, CustomerDetailState>(
        'defaults loyaltyPoints/totalSpent/debt to 0 when absent',
        setUp: () {
          when(() => dioClient.get<dynamic>(any())).thenAnswer((_) async => resp({
                'id': 'c1',
                'storeId': 'store-1',
                'name': 'Ali',
              }));
        },
        build: () => CustomerDetailBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const CustomerDetailRequested(
          storeId: 'store-1',
          customerId: 'c1',
        )),
        expect: () => [
          isA<CustomerDetailLoading>(),
          predicate<CustomerDetailState>((s) =>
              s is CustomerDetailLoaded &&
              s.customer.loyaltyPoints == 0 &&
              s.customer.totalSpent == 0 &&
              s.customer.debt == 0),
        ],
      );

      blocTest<CustomerDetailBloc, CustomerDetailState>(
        'emits [Loading, Error] with offline message on NetworkException',
        setUp: () {
          when(() => dioClient.get<dynamic>(any()))
              .thenThrow(const NetworkException());
        },
        build: () => CustomerDetailBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const CustomerDetailRequested(
          storeId: 'store-1',
          customerId: 'c1',
        )),
        expect: () => [
          isA<CustomerDetailLoading>(),
          const CustomerDetailError('Нет подключения к интернету'),
        ],
      );

      blocTest<CustomerDetailBloc, CustomerDetailState>(
        'emits generic error message (no crash) when response body is null',
        setUp: () {
          when(() => dioClient.get<dynamic>(any()))
              .thenAnswer((_) async => resp(null));
        },
        build: () => CustomerDetailBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const CustomerDetailRequested(
          storeId: 'store-1',
          customerId: 'c1',
        )),
        expect: () => [
          isA<CustomerDetailLoading>(),
          const CustomerDetailError('Не удалось выполнить операцию'),
        ],
      );

      blocTest<CustomerDetailBloc, CustomerDetailState>(
        'emits mapped 404 message on ServerException',
        setUp: () {
          when(() => dioClient.get<dynamic>(any()))
              .thenThrow(const ServerException('not found', statusCode: 404));
        },
        build: () => CustomerDetailBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const CustomerDetailRequested(
          storeId: 'store-1',
          customerId: 'c1',
        )),
        expect: () => [
          isA<CustomerDetailLoading>(),
          const CustomerDetailError('Объект не найден'),
        ],
      );
    });
  });
}
