import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/supplier.dart';
import 'package:dukonpro/domain/repositories/supplier_repository.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_event.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_state.dart';

class MockSupplierRepository extends Mock implements SupplierRepository {}

void main() {
  late MockSupplierRepository repository;

  const supplier1 = Supplier(id: 's1', storeId: 'store-1', name: 'ACME');
  const supplier2 = Supplier(id: 's2', storeId: 'store-1', name: 'Beta');

  setUp(() {
    repository = MockSupplierRepository();
  });

  group('SupplierListBloc', () {
    test('initial state is SupplierListInitial', () {
      final bloc = SupplierListBloc(supplierRepository: repository);
      expect(bloc.state, isA<SupplierListInitial>());
    });

    group('SupplierListLoadRequested', () {
      blocTest<SupplierListBloc, SupplierListState>(
        'emits [Loading, Loaded] on success',
        setUp: () {
          when(() => repository.getSuppliers(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
              )).thenAnswer((_) async => (
                data: [supplier1, supplier2],
                total: 2,
                totalPages: 1,
              ));
        },
        build: () => SupplierListBloc(supplierRepository: repository),
        act: (bloc) => bloc.add(const SupplierListLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SupplierListLoading>(),
          isA<SupplierListLoaded>()
              .having((s) => s.suppliers, 'suppliers', [supplier1, supplier2])
              .having((s) => s.total, 'total', 2)
              .having((s) => s.totalPages, 'totalPages', 1)
              .having((s) => s.currentPage, 'currentPage', 1)
              .having((s) => s.search, 'search', isNull),
        ],
        verify: (_) {
          verify(() => repository.getSuppliers(
                'store-1',
                page: 1,
                search: null,
              )).called(1);
        },
      );

      blocTest<SupplierListBloc, SupplierListState>(
        'passes page and search through to the repository and reflects them in state',
        setUp: () {
          when(() => repository.getSuppliers(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
              )).thenAnswer((_) async => (
                data: [supplier1],
                total: 1,
                totalPages: 1,
              ));
        },
        build: () => SupplierListBloc(supplierRepository: repository),
        act: (bloc) => bloc.add(const SupplierListLoadRequested(
          storeId: 'store-1',
          page: 3,
          search: 'acme',
        )),
        expect: () => [
          isA<SupplierListLoading>(),
          isA<SupplierListLoaded>()
              .having((s) => s.currentPage, 'currentPage', 3)
              .having((s) => s.search, 'search', 'acme'),
        ],
        verify: (_) {
          verify(() => repository.getSuppliers(
                'store-1',
                page: 3,
                search: 'acme',
              )).called(1);
        },
      );

      blocTest<SupplierListBloc, SupplierListState>(
        'emits [Loading, Error] with a mapped message on NetworkException',
        setUp: () {
          when(() => repository.getSuppliers(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
              )).thenThrow(const NetworkException());
        },
        build: () => SupplierListBloc(supplierRepository: repository),
        act: (bloc) => bloc.add(const SupplierListLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SupplierListLoading>(),
          isA<SupplierListError>()
              .having((s) => s.message, 'message', 'Нет подключения к интернету'),
        ],
      );

      blocTest<SupplierListBloc, SupplierListState>(
        'never leaks raw exception text into the error state',
        setUp: () {
          when(() => repository.getSuppliers(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
              )).thenThrow(Exception('DioException [bad response]: http://10.0.2.2:4455/x'));
        },
        build: () => SupplierListBloc(supplierRepository: repository),
        act: (bloc) => bloc.add(const SupplierListLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SupplierListLoading>(),
          predicate<SupplierListState>((s) {
            if (s is! SupplierListError) return false;
            return !s.message.contains('10.0.2.2') &&
                !s.message.contains('DioException') &&
                s.message.isNotEmpty;
          }, 'error set but no leaky internal text'),
        ],
      );
    });

    group('SupplierListSearchChanged', () {
      blocTest<SupplierListBloc, SupplierListState>(
        'triggers a load with the given query as search',
        setUp: () {
          when(() => repository.getSuppliers(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
              )).thenAnswer((_) async => (
                data: [supplier1],
                total: 1,
                totalPages: 1,
              ));
        },
        build: () => SupplierListBloc(supplierRepository: repository),
        act: (bloc) async {
          bloc.add(const SupplierListLoadRequested(storeId: 'store-1'));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const SupplierListSearchChanged('acme'));
        },
        skip: 2,
        expect: () => [
          isA<SupplierListLoading>(),
          isA<SupplierListLoaded>().having((s) => s.search, 'search', 'acme'),
        ],
        verify: (_) {
          verify(() => repository.getSuppliers(
                'store-1',
                page: 1,
                search: 'acme',
              )).called(1);
        },
      );

      blocTest<SupplierListBloc, SupplierListState>(
        'empty query is normalized to null search',
        setUp: () {
          when(() => repository.getSuppliers(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
              )).thenAnswer((_) async => (
                data: <Supplier>[],
                total: 0,
                totalPages: 0,
              ));
        },
        build: () => SupplierListBloc(supplierRepository: repository),
        act: (bloc) => bloc.add(const SupplierListSearchChanged('')),
        expect: () => [
          isA<SupplierListLoading>(),
          isA<SupplierListLoaded>().having((s) => s.search, 'search', isNull),
        ],
        verify: (_) {
          verify(() => repository.getSuppliers(
                any(),
                page: 1,
                search: null,
              )).called(1);
        },
      );
    });
  });
}
