import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/app_message.dart';
import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/data/datasources/local/selected_store_local_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dukonpro/domain/entities/store.dart';
import 'package:dukonpro/domain/repositories/store_repository.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/store/store_event.dart';
import 'package:dukonpro/presentation/blocs/store/store_state.dart';

class MockStoreRepository extends Mock implements StoreRepository {}

void main() {
  late MockStoreRepository repository;

  Store buildStore({String id = 'store-1', String name = 'My Shop'}) => Store(
        id: id,
        ownerId: 'owner-1',
        name: name,
        category: 'grocery',
        createdAt: DateTime(2026, 1, 1),
      );

  setUp(() {
    repository = MockStoreRepository();
  });

  group('StoreBloc', () {
    test('initial state is StoreInitial', () {
      final bloc = StoreBloc(storeRepository: repository);
      expect(bloc.state, isA<StoreInitial>());
    });

    group('StoreLoadRequested', () {
      blocTest<StoreBloc, StoreState>(
        'emits [StoreLoading, StoreLoaded] with first store selected on success',
        setUp: () {
          when(() => repository.getStores())
              .thenAnswer((_) async => [buildStore(id: 's1'), buildStore(id: 's2')]);
        },
        build: () => StoreBloc(storeRepository: repository),
        act: (bloc) => bloc.add(StoreLoadRequested()),
        expect: () => [
          isA<StoreLoading>(),
          predicate<StoreState>((s) =>
              s is StoreLoaded &&
              s.stores.length == 2 &&
              s.selectedStore?.id == 's1'),
        ],
      );

      blocTest<StoreBloc, StoreState>(
        'emits StoreLoaded with null selectedStore when store list is empty',
        setUp: () {
          when(() => repository.getStores()).thenAnswer((_) async => []);
        },
        build: () => StoreBloc(storeRepository: repository),
        act: (bloc) => bloc.add(StoreLoadRequested()),
        expect: () => [
          isA<StoreLoading>(),
          predicate<StoreState>((s) =>
              s is StoreLoaded && s.stores.isEmpty && s.selectedStore == null),
        ],
      );

      blocTest<StoreBloc, StoreState>(
        'emits [StoreLoading, StoreError] with offline message on NetworkException',
        setUp: () {
          when(() => repository.getStores())
              .thenThrow(const NetworkException());
        },
        build: () => StoreBloc(storeRepository: repository),
        act: (bloc) => bloc.add(StoreLoadRequested()),
        expect: () => [
          isA<StoreLoading>(),
          const StoreError(AppMessage.offline),
        ],
      );

      blocTest<StoreBloc, StoreState>(
        'never leaks raw exception text into StoreError message',
        setUp: () {
          when(() => repository.getStores()).thenThrow(
            Exception('DioException [bad response]: http://10.0.2.2:4455/stores'),
          );
        },
        build: () => StoreBloc(storeRepository: repository),
        act: (bloc) => bloc.add(StoreLoadRequested()),
        expect: () => [
          isA<StoreLoading>(),
          // The no-leak property is now carried by the type: an AppMessage
          // cannot contain Dio text or an internal host. Assert the member.
          predicate<StoreState>(
              (s) => s is StoreError && s.message == AppMessage.unknownError,
              'StoreError(unknownError)'),
        ],
      );
    });

    group('StoreCreateRequested', () {
      blocTest<StoreBloc, StoreState>(
        'emits [StoreLoading, StoreLoaded] with newly created store selected',
        setUp: () {
          final created = buildStore(id: 'new-store', name: 'New Shop');
          when(() => repository.createStore(
                name: any(named: 'name'),
                category: any(named: 'category'),
                currency: any(named: 'currency'),
                address: any(named: 'address'),
                phone: any(named: 'phone'),
              )).thenAnswer((_) async => created);
          when(() => repository.getStores())
              .thenAnswer((_) async => [buildStore(id: 's1'), created]);
        },
        build: () => StoreBloc(storeRepository: repository),
        act: (bloc) => bloc.add(const StoreCreateRequested(
          name: 'New Shop',
          category: 'grocery',
        )),
        expect: () => [
          isA<StoreLoading>(),
          predicate<StoreState>((s) =>
              s is StoreLoaded &&
              s.stores.length == 2 &&
              s.selectedStore?.id == 'new-store'),
        ],
        verify: (_) {
          verify(() => repository.createStore(
                name: 'New Shop',
                category: 'grocery',
                currency: 'TJS',
                address: null,
                phone: null,
              )).called(1);
          verify(() => repository.getStores()).called(1);
        },
      );

      blocTest<StoreBloc, StoreState>(
        'emits [StoreLoading, StoreError] with conflict message on 409 ServerException',
        setUp: () {
          when(() => repository.createStore(
                name: any(named: 'name'),
                category: any(named: 'category'),
                currency: any(named: 'currency'),
                address: any(named: 'address'),
                phone: any(named: 'phone'),
              )).thenThrow(
              const ServerException('Store already exists', statusCode: 409));
        },
        build: () => StoreBloc(storeRepository: repository),
        act: (bloc) => bloc.add(const StoreCreateRequested(
          name: 'New Shop',
          category: 'grocery',
        )),
        expect: () => [
          isA<StoreLoading>(),
          const StoreError(AppMessage.conflict),
        ],
        verify: (_) {
          verifyNever(() => repository.getStores());
        },
      );
    });

    group('StoreSelected', () {
      blocTest<StoreBloc, StoreState>(
        'updates selectedStore to the matching store when current state is StoreLoaded',
        build: () => StoreBloc(storeRepository: repository),
        seed: () => StoreLoaded(
          stores: [buildStore(id: 's1'), buildStore(id: 's2')],
          selectedStore: buildStore(id: 's1'),
        ),
        act: (bloc) => bloc.add(const StoreSelected('s2')),
        expect: () => [
          predicate<StoreState>(
              (s) => s is StoreLoaded && s.selectedStore?.id == 's2'),
        ],
      );

      blocTest<StoreBloc, StoreState>(
        'emits nothing when current state is not StoreLoaded',
        build: () => StoreBloc(storeRepository: repository),
        act: (bloc) => bloc.add(const StoreSelected('s1')),
        expect: () => [],
      );
    });

    group('StoreResetRequested', () {
      blocTest<StoreBloc, StoreState>(
        'resets state back to StoreInitial',
        build: () => StoreBloc(storeRepository: repository),
        seed: () => StoreLoaded(stores: [buildStore()]),
        act: (bloc) => bloc.add(StoreResetRequested()),
        expect: () => [isA<StoreInitial>()],
      );
    });
  });

  group('remembering the selected store', () {
    // A cold start has no in-memory selection, so without persistence the user
    // was dropped back into whichever store sorts first.
    Future<SelectedStoreLocalDatasource> freshSelection(
        [Map<String, Object> seed = const {}]) async {
      SharedPreferences.setMockInitialValues(seed);
      return SelectedStoreLocalDatasource(
          await SharedPreferences.getInstance());
    }

    test('should restore the remembered store when the bloc starts cold',
        () async {
      final selection = await freshSelection({'store.selectedId.v1': 's2'});
      when(() => repository.getStores())
          .thenAnswer((_) async => [buildStore(id: 's1'), buildStore(id: 's2')]);

      final bloc =
          StoreBloc(storeRepository: repository, selection: selection);
      addTearDown(bloc.close);
      bloc.add(StoreLoadRequested());
      final loaded = await bloc.stream.firstWhere((s) => s is StoreLoaded)
          as StoreLoaded;

      expect(loaded.selectedStore?.id, 's2');
    });

    test('should fall back to the first store when the remembered one is not '
        'in the account', () async {
      // The id belongs to a previous account; the list is scoped to this one.
      final selection = await freshSelection({'store.selectedId.v1': 'other'});
      when(() => repository.getStores())
          .thenAnswer((_) async => [buildStore(id: 's1')]);

      final bloc =
          StoreBloc(storeRepository: repository, selection: selection);
      addTearDown(bloc.close);
      bloc.add(StoreLoadRequested());
      final loaded = await bloc.stream.firstWhere((s) => s is StoreLoaded)
          as StoreLoaded;

      expect(loaded.selectedStore?.id, 's1');
    });

    test('should remember a store when the user selects it', () async {
      final selection = await freshSelection();
      when(() => repository.getStores())
          .thenAnswer((_) async => [buildStore(id: 's1'), buildStore(id: 's2')]);

      final bloc =
          StoreBloc(storeRepository: repository, selection: selection);
      addTearDown(bloc.close);
      bloc.add(StoreLoadRequested());
      await bloc.stream.firstWhere((s) => s is StoreLoaded);
      bloc.add(const StoreSelected('s2'));
      await bloc.stream.firstWhere(
          (s) => s is StoreLoaded && s.selectedStore?.id == 's2');

      expect(selection.read(), 's2');
    });

    test('should forget the store when the session is reset', () async {
      final selection = await freshSelection({'store.selectedId.v1': 's2'});
      final bloc =
          StoreBloc(storeRepository: repository, selection: selection);
      addTearDown(bloc.close);

      bloc.add(StoreResetRequested());
      await bloc.stream.firstWhere((s) => s is StoreInitial);

      expect(selection.read(), isNull);
    });
  });

}
