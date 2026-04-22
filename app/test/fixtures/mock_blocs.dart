// app/test/fixtures/mock_blocs.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/blocs/store/store_event.dart';
import 'package:dokonpro/presentation/blocs/store/store_state.dart';
import 'package:dokonpro/domain/entities/store.dart';

class MockStoreBloc extends MockBloc<StoreEvent, StoreState>
    implements StoreBloc {}

Store _fakeStore() => Store(
      id: 'test-store-id',
      ownerId: 'test-owner-id',
      name: 'Test Store',
      category: 'retail',
      currency: 'TJS',
      address: '123 Test Street',
      phone: '+992900000000',
      logoUrl: null,
      settings: const {},
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    );

StoreState fakeStoreLoaded() {
  final store = _fakeStore();
  return StoreLoaded(
    stores: [store],
    selectedStore: store,
  );
}
