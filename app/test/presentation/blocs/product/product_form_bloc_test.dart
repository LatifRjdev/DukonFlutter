import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/domain/repositories/product_repository.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_bloc.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_event.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_state.dart';

class MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late MockProductRepository repository;

  Product mkProduct({
    String id = 'p1',
    String storeId = 'store-1',
    String? categoryId,
    String? sku,
    String? barcode,
    String? description,
    double? costPrice,
    double sellPrice = 10,
    double? wholesalePrice,
    int quantity = 3,
    int minQuantity = 1,
    String unit = 'PCS',
    String? supplierId,
    String? imageUrl,
  }) =>
      Product(
        id: id,
        storeId: storeId,
        categoryId: categoryId,
        supplierId: supplierId,
        name: 'Apple',
        sku: sku,
        barcode: barcode,
        description: description,
        costPrice: costPrice,
        sellPrice: sellPrice,
        wholesalePrice: wholesalePrice,
        quantity: quantity,
        minQuantity: minQuantity,
        unit: unit,
        imageUrl: imageUrl,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = MockProductRepository();
  });

  group('ProductFormBloc', () {
    test('initial state is a fresh ProductFormState', () {
      final bloc = ProductFormBloc(productRepository: repository);
      expect(bloc.state.currentStep, 0);
      expect(bloc.state.productData, isEmpty);
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.isSubmitting, isFalse);
      expect(bloc.state.error, isNull);
      expect(bloc.state.editingProductId, isNull);
      expect(bloc.state.isSuccess, isFalse);
      expect(bloc.state.isEditing, isFalse);
    });

    group('ProductFormUpdateStep', () {
      blocTest<ProductFormBloc, ProductFormState>(
        'updates currentStep and clears any existing error',
        build: () => ProductFormBloc(productRepository: repository),
        seed: () => const ProductFormState(currentStep: 0, error: 'boom'),
        act: (bloc) => bloc.add(const ProductFormUpdateStep(2)),
        expect: () => [
          predicate<ProductFormState>(
              (s) => s.currentStep == 2 && s.error == null),
        ],
      );
    });

    group('ProductFormSaveStep', () {
      blocTest<ProductFormBloc, ProductFormState>(
        'merges new data into productData and advances to the next step',
        build: () => ProductFormBloc(productRepository: repository),
        act: (bloc) => bloc.add(const ProductFormSaveStep(
          step: 0,
          data: {'name': 'Apple', 'sku': 'A1'},
        )),
        expect: () => [
          predicate<ProductFormState>((s) =>
              s.currentStep == 1 &&
              s.productData['name'] == 'Apple' &&
              s.productData['sku'] == 'A1'),
        ],
      );

      blocTest<ProductFormBloc, ProductFormState>(
        'keeps previously saved keys when saving a later step',
        build: () => ProductFormBloc(productRepository: repository),
        seed: () => const ProductFormState(
          currentStep: 1,
          productData: {'name': 'Apple'},
        ),
        act: (bloc) => bloc.add(const ProductFormSaveStep(
          step: 1,
          data: {'sellPrice': 10.0},
        )),
        expect: () => [
          predicate<ProductFormState>((s) =>
              s.productData['name'] == 'Apple' &&
              s.productData['sellPrice'] == 10.0 &&
              s.currentStep == 2),
        ],
      );

      blocTest<ProductFormBloc, ProductFormState>(
        'overwrites a key that is re-saved with a new value',
        build: () => ProductFormBloc(productRepository: repository),
        seed: () => const ProductFormState(
          currentStep: 0,
          productData: {'name': 'Old name'},
        ),
        act: (bloc) => bloc.add(const ProductFormSaveStep(
          step: 0,
          data: {'name': 'New name'},
        )),
        expect: () => [
          predicate<ProductFormState>((s) => s.productData['name'] == 'New name'),
        ],
      );

      blocTest<ProductFormBloc, ProductFormState>(
        'does not advance currentStep past totalSteps - 1 when saving the last step',
        build: () => ProductFormBloc(productRepository: repository),
        seed: () => const ProductFormState(
          currentStep: 2,
          productData: {'quantity': 5},
        ),
        act: (bloc) => bloc.add(const ProductFormSaveStep(
          step: 2,
          data: {'unit': 'KG'},
        )),
        expect: () => [
          predicate<ProductFormState>(
              (s) => s.currentStep == 2 && s.productData['unit'] == 'KG'),
        ],
      );
    });

    group('ProductFormSubmit — create path', () {
      blocTest<ProductFormBloc, ProductFormState>(
        'calls createProduct (not updateProduct) when editingProductId is null',
        setUp: () {
          when(() => repository.createProduct(any(), any()))
              .thenAnswer((_) async => mkProduct());
        },
        build: () => ProductFormBloc(productRepository: repository),
        seed: () => const ProductFormState(
          productData: {'name': 'Apple', 'sellPrice': 10.0},
        ),
        act: (bloc) => bloc.add(const ProductFormSubmit(storeId: 'store-1')),
        expect: () => [
          predicate<ProductFormState>((s) => s.isSubmitting && s.error == null),
          predicate<ProductFormState>(
              (s) => !s.isSubmitting && s.isSuccess),
        ],
        verify: (_) {
          final captured = verify(
            () => repository.createProduct(captureAny(), captureAny()),
          ).captured;
          expect(captured[0], 'store-1');
          final payload = captured[1] as Map<String, dynamic>;
          expect(payload['name'], 'Apple');
          expect(payload['sellPrice'], 10.0);
          verifyNever(() => repository.updateProduct(any(), any(), any()));
        },
      );
    });

    group('ProductFormSubmit — update path', () {
      blocTest<ProductFormBloc, ProductFormState>(
        'calls updateProduct (not createProduct) when editingProductId is set',
        setUp: () {
          when(() => repository.updateProduct(any(), any(), any()))
              .thenAnswer((_) async => mkProduct());
        },
        build: () => ProductFormBloc(productRepository: repository),
        seed: () => const ProductFormState(
          editingProductId: 'p1',
          productData: {'name': 'Updated apple'},
        ),
        act: (bloc) => bloc.add(const ProductFormSubmit(storeId: 'store-1')),
        expect: () => [
          predicate<ProductFormState>((s) => s.isSubmitting),
          predicate<ProductFormState>(
              (s) => !s.isSubmitting && s.isSuccess),
        ],
        verify: (_) {
          final captured = verify(
            () => repository.updateProduct(
                captureAny(), captureAny(), captureAny()),
          ).captured;
          expect(captured[0], 'store-1');
          expect(captured[1], 'p1');
          expect((captured[2] as Map)['name'], 'Updated apple');
          verifyNever(() => repository.createProduct(any(), any()));
        },
      );
    });

    group('ProductFormSubmit — error paths', () {
      blocTest<ProductFormBloc, ProductFormState>(
        'maps NetworkException to the offline message and clears isSubmitting',
        setUp: () {
          when(() => repository.createProduct(any(), any()))
              .thenThrow(const NetworkException());
        },
        build: () => ProductFormBloc(productRepository: repository),
        seed: () => const ProductFormState(productData: {'name': 'Apple'}),
        act: (bloc) => bloc.add(const ProductFormSubmit(storeId: 'store-1')),
        expect: () => [
          predicate<ProductFormState>((s) => s.isSubmitting),
          predicate<ProductFormState>((s) =>
              !s.isSubmitting &&
              !s.isSuccess &&
              s.error == 'Нет подключения к интернету'),
        ],
      );

      blocTest<ProductFormBloc, ProductFormState>(
        'maps ServerException(400) to the validation message',
        setUp: () {
          when(() => repository.createProduct(any(), any())).thenThrow(
              const ServerException('bad data', statusCode: 400));
        },
        build: () => ProductFormBloc(productRepository: repository),
        seed: () => const ProductFormState(productData: {'name': 'Apple'}),
        act: (bloc) => bloc.add(const ProductFormSubmit(storeId: 'store-1')),
        expect: () => [
          predicate<ProductFormState>((s) => s.isSubmitting),
          predicate<ProductFormState>(
              (s) => s.error == 'Некорректные данные'),
        ],
      );

      blocTest<ProductFormBloc, ProductFormState>(
        'maps UnauthorizedException to the "sign in again" message',
        setUp: () {
          when(() => repository.createProduct(any(), any()))
              .thenThrow(const UnauthorizedException());
        },
        build: () => ProductFormBloc(productRepository: repository),
        seed: () => const ProductFormState(productData: {'name': 'Apple'}),
        act: (bloc) => bloc.add(const ProductFormSubmit(storeId: 'store-1')),
        expect: () => [
          predicate<ProductFormState>((s) => s.isSubmitting),
          predicate<ProductFormState>(
              (s) => s.error == 'Сессия истекла. Войдите снова.'),
        ],
      );

      blocTest<ProductFormBloc, ProductFormState>(
        'maps an unknown exception type to the generic fallback message',
        setUp: () {
          when(() => repository.createProduct(any(), any()))
              .thenThrow(Exception('weird'));
        },
        build: () => ProductFormBloc(productRepository: repository),
        seed: () => const ProductFormState(productData: {'name': 'Apple'}),
        act: (bloc) => bloc.add(const ProductFormSubmit(storeId: 'store-1')),
        expect: () => [
          predicate<ProductFormState>((s) => s.isSubmitting),
          predicate<ProductFormState>(
              (s) => s.error == 'Не удалось выполнить операцию'),
        ],
      );
    });

    group('ProductFormLoadProduct', () {
      blocTest<ProductFormBloc, ProductFormState>(
        'loads a product and seeds productData + editingProductId from it',
        setUp: () {
          when(() => repository.getProduct('store-1', 'p1')).thenAnswer(
            (_) async => mkProduct(
              id: 'p1',
              sku: 'A1',
              barcode: '123456',
              costPrice: 5,
              sellPrice: 10,
              quantity: 7,
              minQuantity: 2,
              unit: 'KG',
            ),
          );
        },
        build: () => ProductFormBloc(productRepository: repository),
        act: (bloc) => bloc.add(const ProductFormLoadProduct(
          storeId: 'store-1',
          productId: 'p1',
        )),
        expect: () => [
          predicate<ProductFormState>((s) => s.isLoading && s.error == null),
          predicate<ProductFormState>((s) =>
              !s.isLoading &&
              s.editingProductId == 'p1' &&
              s.isEditing &&
              s.productData['name'] == 'Apple' &&
              s.productData['sku'] == 'A1' &&
              s.productData['barcode'] == '123456' &&
              s.productData['costPrice'] == 5 &&
              s.productData['sellPrice'] == 10 &&
              s.productData['quantity'] == 7 &&
              s.productData['minQuantity'] == 2 &&
              s.productData['unit'] == 'KG'),
        ],
      );

      blocTest<ProductFormBloc, ProductFormState>(
        'maps a load failure to isLoading=false + user-facing error',
        setUp: () {
          when(() => repository.getProduct('store-1', 'missing')).thenThrow(
              const ServerException('not found', statusCode: 404));
        },
        build: () => ProductFormBloc(productRepository: repository),
        act: (bloc) => bloc.add(const ProductFormLoadProduct(
          storeId: 'store-1',
          productId: 'missing',
        )),
        expect: () => [
          predicate<ProductFormState>((s) => s.isLoading),
          predicate<ProductFormState>((s) =>
              !s.isLoading &&
              s.error == 'Объект не найден' &&
              s.editingProductId == null),
        ],
      );
    });

    group('ProductFormReset', () {
      blocTest<ProductFormBloc, ProductFormState>(
        'resets to a fresh ProductFormState regardless of prior dirty state',
        build: () => ProductFormBloc(productRepository: repository),
        seed: () => const ProductFormState(
          currentStep: 2,
          productData: {'name': 'Dirty'},
          isSubmitting: true,
          error: 'boom',
          editingProductId: 'p1',
          isSuccess: true,
        ),
        act: (bloc) => bloc.add(ProductFormReset()),
        expect: () => [const ProductFormState()],
      );
    });
  });
}
