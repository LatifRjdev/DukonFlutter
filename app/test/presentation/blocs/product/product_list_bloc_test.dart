import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/domain/repositories/product_repository.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_event.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_state.dart';

class MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late MockProductRepository repository;

  Product mkProduct({String id = 'p1', String storeId = 'store-1'}) =>
      Product(
        id: id,
        storeId: storeId,
        name: 'Apple',
        sellPrice: 10,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  setUp(() {
    repository = MockProductRepository();
  });

  group('ProductListBloc', () {
    test('initial state is ProductListInitial', () {
      final bloc = ProductListBloc(productRepository: repository);
      expect(bloc.state, isA<ProductListInitial>());
    });

    group('ProductListLoadRequested', () {
      blocTest<ProductListBloc, ProductListState>(
        'emits [Loading, Loaded] with products/total/totalPages/currentPage on success',
        setUp: () {
          when(() => repository.getProducts(
                'store-1',
                page: 1,
                limit: 20,
                search: null,
                categoryId: null,
                inStock: null,
                lowStock: null,
                sortBy: null,
                sortOrder: null,
              )).thenAnswer((_) async => (
                data: [mkProduct(id: 'p1'), mkProduct(id: 'p2')],
                total: 2,
                totalPages: 1,
              ));
        },
        build: () => ProductListBloc(productRepository: repository),
        act: (bloc) => bloc.add(const ProductListLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<ProductListLoading>(),
          predicate<ProductListState>((s) =>
              s is ProductListLoaded &&
              s.products.length == 2 &&
              s.total == 2 &&
              s.totalPages == 1 &&
              s.currentPage == 1 &&
              s.search == null &&
              s.categoryId == null),
        ],
      );

      blocTest<ProductListBloc, ProductListState>(
        'passes through search/categoryId/page to the repository and the resulting state',
        setUp: () {
          when(() => repository.getProducts(
                'store-1',
                page: 3,
                limit: 20,
                search: 'apple',
                categoryId: 'cat-1',
                inStock: null,
                lowStock: null,
                sortBy: null,
                sortOrder: null,
              )).thenAnswer((_) async => (
                data: [mkProduct()],
                total: 41,
                totalPages: 3,
              ));
        },
        build: () => ProductListBloc(productRepository: repository),
        act: (bloc) => bloc.add(const ProductListLoadRequested(
          storeId: 'store-1',
          search: 'apple',
          categoryId: 'cat-1',
          page: 3,
        )),
        expect: () => [
          isA<ProductListLoading>(),
          predicate<ProductListState>((s) =>
              s is ProductListLoaded &&
              s.search == 'apple' &&
              s.categoryId == 'cat-1' &&
              s.currentPage == 3 &&
              s.totalPages == 3 &&
              s.total == 41),
        ],
      );

      blocTest<ProductListBloc, ProductListState>(
        'emits [Loading, Error] with a mapped message when the repository throws',
        setUp: () {
          when(() => repository.getProducts(
                'store-1',
                page: 1,
                limit: 20,
                search: null,
                categoryId: null,
                inStock: null,
                lowStock: null,
                sortBy: null,
                sortOrder: null,
              )).thenThrow(const NetworkException());
        },
        build: () => ProductListBloc(productRepository: repository),
        act: (bloc) => bloc.add(const ProductListLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<ProductListLoading>(),
          const ProductListError('Нет подключения к интернету'),
        ],
      );

      blocTest<ProductListBloc, ProductListState>(
        'maps a 500 ServerException to the server-error message',
        setUp: () {
          when(() => repository.getProducts(
                'store-1',
                page: 1,
                limit: 20,
                search: null,
                categoryId: null,
                inStock: null,
                lowStock: null,
                sortBy: null,
                sortOrder: null,
              )).thenThrow(
                  const ServerException('boom', statusCode: 500));
        },
        build: () => ProductListBloc(productRepository: repository),
        act: (bloc) => bloc.add(const ProductListLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<ProductListLoading>(),
          const ProductListError('Ошибка сервера — попробуйте позже'),
        ],
      );
    });

    group('ProductListSearchChanged', () {
      blocTest<ProductListBloc, ProductListState>(
        'reloads with the new search query using the store id from the last load',
        setUp: () {
          when(() => repository.getProducts(
                'store-1',
                page: 1,
                limit: 20,
                search: null,
                categoryId: null,
                inStock: null,
                lowStock: null,
                sortBy: null,
                sortOrder: null,
              )).thenAnswer((_) async => (
                data: <Product>[],
                total: 0,
                totalPages: 0,
              ));
          when(() => repository.getProducts(
                'store-1',
                page: 1,
                limit: 20,
                search: 'bread',
                categoryId: null,
                inStock: null,
                lowStock: null,
                sortBy: null,
                sortOrder: null,
              )).thenAnswer((_) async => (
                data: [mkProduct()],
                total: 1,
                totalPages: 1,
              ));
        },
        build: () => ProductListBloc(productRepository: repository),
        act: (bloc) async {
          bloc.add(const ProductListLoadRequested(storeId: 'store-1'));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const ProductListSearchChanged('bread'));
        },
        expect: () => [
          isA<ProductListLoading>(),
          isA<ProductListLoaded>(),
          isA<ProductListLoading>(),
          predicate<ProductListState>(
              (s) => s is ProductListLoaded && s.search == 'bread'),
        ],
        verify: (_) {
          verify(() => repository.getProducts(
                'store-1',
                page: 1,
                limit: 20,
                search: 'bread',
                categoryId: null,
                inStock: null,
                lowStock: null,
                sortBy: null,
                sortOrder: null,
              )).called(1);
        },
      );

      blocTest<ProductListBloc, ProductListState>(
        'uses an empty store id when no load has happened yet',
        setUp: () {
          when(() => repository.getProducts(
                '',
                page: 1,
                limit: 20,
                search: 'x',
                categoryId: null,
                inStock: null,
                lowStock: null,
                sortBy: null,
                sortOrder: null,
              )).thenAnswer((_) async => (
                data: <Product>[],
                total: 0,
                totalPages: 0,
              ));
        },
        build: () => ProductListBloc(productRepository: repository),
        act: (bloc) => bloc.add(const ProductListSearchChanged('x')),
        expect: () => [
          isA<ProductListLoading>(),
          isA<ProductListLoaded>(),
        ],
      );
    });

    group('ProductListCategoryFilterChanged', () {
      blocTest<ProductListBloc, ProductListState>(
        'reloads with the new categoryId and drops any active search filter',
        setUp: () {
          when(() => repository.getProducts(
                'store-1',
                page: 1,
                limit: 20,
                search: 'apple',
                categoryId: null,
                inStock: null,
                lowStock: null,
                sortBy: null,
                sortOrder: null,
              )).thenAnswer((_) async => (
                data: [mkProduct()],
                total: 1,
                totalPages: 1,
              ));
          when(() => repository.getProducts(
                'store-1',
                page: 1,
                limit: 20,
                search: null,
                categoryId: 'cat-9',
                inStock: null,
                lowStock: null,
                sortBy: null,
                sortOrder: null,
              )).thenAnswer((_) async => (
                data: [mkProduct(), mkProduct(id: 'p2')],
                total: 2,
                totalPages: 1,
              ));
        },
        build: () => ProductListBloc(productRepository: repository),
        act: (bloc) async {
          bloc.add(const ProductListLoadRequested(storeId: 'store-1', search: 'apple'));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const ProductListCategoryFilterChanged('cat-9'));
        },
        expect: () => [
          isA<ProductListLoading>(),
          predicate<ProductListState>(
              (s) => s is ProductListLoaded && s.search == 'apple'),
          isA<ProductListLoading>(),
          predicate<ProductListState>((s) =>
              s is ProductListLoaded &&
              s.categoryId == 'cat-9' &&
              s.search == null &&
              s.products.length == 2),
        ],
      );
    });

    group('ProductDeleteRequested', () {
      blocTest<ProductListBloc, ProductListState>(
        'deletes the product then reloads the list for the given store',
        setUp: () {
          when(() => repository.deleteProduct('store-1', 'p1'))
              .thenAnswer((_) async {});
          when(() => repository.getProducts(
                'store-1',
                page: 1,
                limit: 20,
                search: null,
                categoryId: null,
                inStock: null,
                lowStock: null,
                sortBy: null,
                sortOrder: null,
              )).thenAnswer((_) async => (
                data: <Product>[],
                total: 0,
                totalPages: 0,
              ));
        },
        build: () => ProductListBloc(productRepository: repository),
        act: (bloc) => bloc
            .add(const ProductDeleteRequested(storeId: 'store-1', productId: 'p1')),
        expect: () => [
          isA<ProductListLoading>(),
          isA<ProductListLoaded>(),
        ],
        verify: (_) {
          verify(() => repository.deleteProduct('store-1', 'p1')).called(1);
        },
      );

      blocTest<ProductListBloc, ProductListState>(
        'emits Error and never reloads when deleteProduct throws',
        setUp: () {
          when(() => repository.deleteProduct('store-1', 'p1'))
              .thenThrow(const ServerException('nope', statusCode: 403));
        },
        build: () => ProductListBloc(productRepository: repository),
        act: (bloc) => bloc
            .add(const ProductDeleteRequested(storeId: 'store-1', productId: 'p1')),
        expect: () => [
          const ProductListError('Недостаточно прав'),
        ],
        verify: (_) {
          verifyNever(() => repository.getProducts(
                any(),
                page: any(named: 'page'),
                limit: any(named: 'limit'),
                search: any(named: 'search'),
                categoryId: any(named: 'categoryId'),
                inStock: any(named: 'inStock'),
                lowStock: any(named: 'lowStock'),
                sortBy: any(named: 'sortBy'),
                sortOrder: any(named: 'sortOrder'),
              ));
        },
      );
    });
  });
}
