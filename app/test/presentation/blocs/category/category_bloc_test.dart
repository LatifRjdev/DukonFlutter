import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/category.dart';
import 'package:dukonpro/domain/repositories/category_repository.dart';
import 'package:dukonpro/presentation/blocs/category/category_bloc.dart';
import 'package:dukonpro/presentation/blocs/category/category_event.dart';
import 'package:dukonpro/presentation/blocs/category/category_state.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  late MockCategoryRepository repository;

  const category1 = Category(id: 'c1', storeId: 'store-1', name: 'Drinks');
  const category2 = Category(id: 'c2', storeId: 'store-1', name: 'Snacks');

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = MockCategoryRepository();
  });

  group('CategoryBloc', () {
    test('initial state is CategoryInitial', () {
      final bloc = CategoryBloc(categoryRepository: repository);
      expect(bloc.state, isA<CategoryInitial>());
    });

    group('CategoryLoadRequested', () {
      blocTest<CategoryBloc, CategoryState>(
        'emits [Loading, Loaded] with categories on success',
        setUp: () {
          when(() => repository.getCategories('store-1'))
              .thenAnswer((_) async => [category1, category2]);
        },
        build: () => CategoryBloc(categoryRepository: repository),
        act: (bloc) => bloc.add(const CategoryLoadRequested('store-1')),
        expect: () => [
          isA<CategoryLoading>(),
          isA<CategoryLoaded>().having(
            (s) => s.categories,
            'categories',
            [category1, category2],
          ),
        ],
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [Loading, Loaded] with empty list when repository returns none',
        setUp: () {
          when(() => repository.getCategories('store-1'))
              .thenAnswer((_) async => []);
        },
        build: () => CategoryBloc(categoryRepository: repository),
        act: (bloc) => bloc.add(const CategoryLoadRequested('store-1')),
        expect: () => [
          isA<CategoryLoading>(),
          isA<CategoryLoaded>().having((s) => s.categories, 'categories', isEmpty),
        ],
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [Loading, Error] with offline message on NetworkException',
        setUp: () {
          when(() => repository.getCategories('store-1'))
              .thenThrow(const NetworkException());
        },
        build: () => CategoryBloc(categoryRepository: repository),
        act: (bloc) => bloc.add(const CategoryLoadRequested('store-1')),
        expect: () => [
          isA<CategoryLoading>(),
          isA<CategoryError>().having(
            (s) => s.message,
            'message',
            'Нет подключения к интернету',
          ),
        ],
      );

      blocTest<CategoryBloc, CategoryState>(
        'never leaks raw exception text into state.message',
        setUp: () {
          when(() => repository.getCategories('store-1')).thenThrow(
            Exception('DioException [bad response]: http://10.0.2.2:4455/categories'),
          );
        },
        build: () => CategoryBloc(categoryRepository: repository),
        act: (bloc) => bloc.add(const CategoryLoadRequested('store-1')),
        expect: () => [
          isA<CategoryLoading>(),
          isA<CategoryError>().having((s) {
            final message = s.message;
            return !message.contains('10.0.2.2') &&
                !message.contains('DioException') &&
                message.isNotEmpty;
          }, 'sanitized message', true),
        ],
      );
    });

    group('CategoryCreateRequested', () {
      blocTest<CategoryBloc, CategoryState>(
        'creates the category then reloads, emitting [Loading, Loaded]',
        setUp: () {
          when(() => repository.createCategory('store-1', any()))
              .thenAnswer((_) async => category1);
          when(() => repository.getCategories('store-1'))
              .thenAnswer((_) async => [category1]);
        },
        build: () => CategoryBloc(categoryRepository: repository),
        act: (bloc) => bloc.add(const CategoryCreateRequested(
          storeId: 'store-1',
          name: 'Drinks',
          icon: 'drink',
          color: '#FF0000',
          parentId: 'p1',
        )),
        expect: () => [
          isA<CategoryLoading>(),
          isA<CategoryLoaded>().having((s) => s.categories, 'categories', [category1]),
        ],
        verify: (_) {
          final captured = verify(
            () => repository.createCategory('store-1', captureAny()),
          ).captured;
          final payload = captured.single as Map<String, dynamic>;
          expect(payload['name'], 'Drinks');
          expect(payload['icon'], 'drink');
          expect(payload['color'], '#FF0000');
          expect(payload['parentId'], 'p1');
        },
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [Error] and never reloads when createCategory throws',
        setUp: () {
          when(() => repository.createCategory('store-1', any()))
              .thenThrow(const ServerException('Bad', statusCode: 400));
        },
        build: () => CategoryBloc(categoryRepository: repository),
        act: (bloc) => bloc.add(const CategoryCreateRequested(
          storeId: 'store-1',
          name: 'Drinks',
        )),
        expect: () => [
          isA<CategoryError>().having(
            (s) => s.message,
            'message',
            'Некорректные данные',
          ),
        ],
        verify: (_) {
          verifyNever(() => repository.getCategories(any()));
        },
      );
    });

    group('CategoryUpdateRequested', () {
      blocTest<CategoryBloc, CategoryState>(
        'updates the category with only name, then reloads',
        setUp: () {
          when(() => repository.updateCategory('store-1', 'c1', any()))
              .thenAnswer((_) async => category1);
          when(() => repository.getCategories('store-1'))
              .thenAnswer((_) async => [category1]);
        },
        build: () => CategoryBloc(categoryRepository: repository),
        act: (bloc) => bloc.add(const CategoryUpdateRequested(
          storeId: 'store-1',
          id: 'c1',
          name: 'Renamed',
        )),
        expect: () => [
          isA<CategoryLoading>(),
          isA<CategoryLoaded>(),
        ],
        verify: (_) {
          final captured = verify(
            () => repository.updateCategory('store-1', 'c1', captureAny()),
          ).captured;
          final payload = captured.single as Map<String, dynamic>;
          expect(payload, {'name': 'Renamed'});
        },
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [Error] when updateCategory throws',
        setUp: () {
          when(() => repository.updateCategory('store-1', 'missing', any()))
              .thenThrow(const CacheException('Category not found in local storage'));
        },
        build: () => CategoryBloc(categoryRepository: repository),
        act: (bloc) => bloc.add(const CategoryUpdateRequested(
          storeId: 'store-1',
          id: 'missing',
          name: 'x',
        )),
        expect: () => [
          isA<CategoryError>().having(
            (s) => s.message,
            'message',
            'Ошибка локального хранилища',
          ),
        ],
      );
    });

    group('CategoryDeleteRequested', () {
      blocTest<CategoryBloc, CategoryState>(
        'deletes the category then reloads, emitting [Loading, Loaded]',
        setUp: () {
          when(() => repository.deleteCategory('store-1', 'c1'))
              .thenAnswer((_) async {});
          when(() => repository.getCategories('store-1'))
              .thenAnswer((_) async => []);
        },
        build: () => CategoryBloc(categoryRepository: repository),
        act: (bloc) => bloc.add(const CategoryDeleteRequested(
          storeId: 'store-1',
          id: 'c1',
        )),
        expect: () => [
          isA<CategoryLoading>(),
          isA<CategoryLoaded>().having((s) => s.categories, 'categories', isEmpty),
        ],
        verify: (_) {
          verify(() => repository.deleteCategory('store-1', 'c1')).called(1);
        },
      );

      blocTest<CategoryBloc, CategoryState>(
        'emits [Error] with unauthorized message when deleteCategory throws 401',
        setUp: () {
          when(() => repository.deleteCategory('store-1', 'c1'))
              .thenThrow(const UnauthorizedException());
        },
        build: () => CategoryBloc(categoryRepository: repository),
        act: (bloc) => bloc.add(const CategoryDeleteRequested(
          storeId: 'store-1',
          id: 'c1',
        )),
        expect: () => [
          isA<CategoryError>().having(
            (s) => s.message,
            'message',
            'Сессия истекла. Войдите снова.',
          ),
        ],
        verify: (_) {
          verifyNever(() => repository.getCategories(any()));
        },
      );
    });
  });
}
