import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/customer.dart';
import 'package:dukonpro/domain/repositories/customer_repository.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_event.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_state.dart';

class MockCustomerRepository extends Mock implements CustomerRepository {}

void main() {
  late MockCustomerRepository repository;

  const customer = Customer(id: 'c1', storeId: 'store-1', name: 'Ali');

  setUp(() {
    repository = MockCustomerRepository();
  });

  group('CustomerListBloc', () {
    test('initial state is CustomerListInitial', () {
      final bloc = CustomerListBloc(customerRepository: repository);
      expect(bloc.state, isA<CustomerListInitial>());
    });

    group('CustomerListLoadRequested', () {
      blocTest<CustomerListBloc, CustomerListState>(
        'emits [Loading, Loaded] on success',
        setUp: () {
          when(() => repository.getCustomers(
                'store-1',
                page: 1,
                search: null,
              )).thenAnswer((_) async => (
                data: [customer],
                total: 1,
                totalPages: 1,
              ));
        },
        build: () => CustomerListBloc(customerRepository: repository),
        act: (bloc) => bloc.add(const CustomerListLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<CustomerListLoading>(),
          predicate<CustomerListState>((s) =>
              s is CustomerListLoaded &&
              s.customers.length == 1 &&
              s.total == 1 &&
              s.totalPages == 1 &&
              s.currentPage == 1 &&
              s.search == null),
        ],
      );

      blocTest<CustomerListBloc, CustomerListState>(
        'emits [Loading, Error] with mapped message on repository failure',
        setUp: () {
          when(() => repository.getCustomers(
                'store-1',
                page: 1,
                search: null,
              )).thenThrow(const NetworkException());
        },
        build: () => CustomerListBloc(customerRepository: repository),
        act: (bloc) => bloc.add(const CustomerListLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<CustomerListLoading>(),
          const CustomerListError('Нет подключения к интернету'),
        ],
      );

      blocTest<CustomerListBloc, CustomerListState>(
        'never leaks raw exception text into CustomerListError.message',
        setUp: () {
          when(() => repository.getCustomers(
                'store-1',
                page: 1,
                search: null,
              )).thenThrow(Exception('DioException [bad response]: http://10.0.2.2:4455'));
        },
        build: () => CustomerListBloc(customerRepository: repository),
        act: (bloc) => bloc.add(const CustomerListLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<CustomerListLoading>(),
          predicate<CustomerListState>((s) {
            if (s is! CustomerListError) return false;
            return !s.message.contains('DioException') &&
                !s.message.contains('10.0.2.2') &&
                s.message.isNotEmpty;
          }, 'error message has no leaky internal text'),
        ],
      );
    });

    group('CustomerListSearchChanged', () {
      blocTest<CustomerListBloc, CustomerListState>(
        'converts empty query to null search and reloads with last storeId',
        setUp: () {
          when(() => repository.getCustomers(
                'store-1',
                page: 1,
                search: null,
              )).thenAnswer((_) async => (
                data: <Customer>[],
                total: 0,
                totalPages: 0,
              ));
        },
        build: () => CustomerListBloc(customerRepository: repository),
        act: (bloc) async {
          bloc.add(const CustomerListLoadRequested(storeId: 'store-1'));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const CustomerListSearchChanged(''));
        },
        verify: (_) {
          verify(() => repository.getCustomers(
                'store-1',
                page: 1,
                search: null,
              )).called(2);
        },
      );

      blocTest<CustomerListBloc, CustomerListState>(
        'forwards non-empty query as search term',
        setUp: () {
          when(() => repository.getCustomers(
                'store-1',
                page: 1,
                search: null,
              )).thenAnswer((_) async => (
                data: <Customer>[],
                total: 0,
                totalPages: 0,
              ));
          when(() => repository.getCustomers(
                'store-1',
                page: 1,
                search: 'ali',
              )).thenAnswer((_) async => (
                data: [customer],
                total: 1,
                totalPages: 1,
              ));
        },
        build: () => CustomerListBloc(customerRepository: repository),
        act: (bloc) async {
          bloc.add(const CustomerListLoadRequested(storeId: 'store-1'));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const CustomerListSearchChanged('ali'));
        },
        verify: (_) {
          verify(() => repository.getCustomers(
                'store-1',
                page: 1,
                search: 'ali',
              )).called(1);
        },
      );
    });

    group('CustomerCreateRequested', () {
      blocTest<CustomerListBloc, CustomerListState>(
        'emits [FormLoading, FormSuccess(isEditing: false)] on success',
        setUp: () {
          when(() => repository.createCustomer('store-1', any()))
              .thenAnswer((_) async => customer);
        },
        build: () => CustomerListBloc(customerRepository: repository),
        act: (bloc) => bloc.add(const CustomerCreateRequested(
          storeId: 'store-1',
          data: {'name': 'Ali'},
        )),
        expect: () => [
          isA<CustomerFormLoading>(),
          predicate<CustomerListState>((s) =>
              s is CustomerFormSuccess &&
              s.customer == customer &&
              s.isEditing == false),
        ],
      );

      blocTest<CustomerListBloc, CustomerListState>(
        'emits [FormLoading, FormError] on failure',
        setUp: () {
          when(() => repository.createCustomer('store-1', any()))
              .thenThrow(const ServerException('bad', statusCode: 400));
        },
        build: () => CustomerListBloc(customerRepository: repository),
        act: (bloc) => bloc.add(const CustomerCreateRequested(
          storeId: 'store-1',
          data: {'name': 'Ali'},
        )),
        expect: () => [
          isA<CustomerFormLoading>(),
          const CustomerFormError('Некорректные данные'),
        ],
      );
    });

    group('CustomerUpdateRequested', () {
      blocTest<CustomerListBloc, CustomerListState>(
        'emits [FormLoading, FormSuccess(isEditing: true)] on success',
        setUp: () {
          when(() => repository.updateCustomer('store-1', 'c1', any()))
              .thenAnswer((_) async => customer);
        },
        build: () => CustomerListBloc(customerRepository: repository),
        act: (bloc) => bloc.add(const CustomerUpdateRequested(
          storeId: 'store-1',
          customerId: 'c1',
          data: {'name': 'Ali 2'},
        )),
        expect: () => [
          isA<CustomerFormLoading>(),
          predicate<CustomerListState>((s) =>
              s is CustomerFormSuccess &&
              s.customer == customer &&
              s.isEditing == true),
        ],
      );

      blocTest<CustomerListBloc, CustomerListState>(
        'emits [FormLoading, FormError] on failure',
        setUp: () {
          when(() => repository.updateCustomer('store-1', 'c1', any()))
              .thenThrow(const UnauthorizedException());
        },
        build: () => CustomerListBloc(customerRepository: repository),
        act: (bloc) => bloc.add(const CustomerUpdateRequested(
          storeId: 'store-1',
          customerId: 'c1',
          data: {'name': 'Ali 2'},
        )),
        expect: () => [
          isA<CustomerFormLoading>(),
          const CustomerFormError('Сессия истекла. Войдите снова.'),
        ],
      );
    });
  });
}
