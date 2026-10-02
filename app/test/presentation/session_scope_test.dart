import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/domain/entities/store.dart';
import 'package:dukonpro/domain/repositories/store_repository.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/store/store_event.dart';
import 'package:dukonpro/presentation/blocs/store/store_state.dart';
import 'package:dukonpro/presentation/widgets/common/store_scope.dart';

/// Stand-in for any session-scoped bloc. The contract under test is about
/// provider lifetime, not about any particular bloc's behaviour.
class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);
  void bump() => emit(state + 1);
}

/// Mirrors app.dart: a keyed MultiBlocProvider wrapping the route content,
/// sitting below the router and above every screen.
Widget _subtree(String sessionKey, void Function(_CounterCubit) capture) {
  return MaterialApp(
    home: MultiBlocProvider(
      key: ValueKey(sessionKey),
      providers: [BlocProvider(create: (_) => _CounterCubit())],
      child: Builder(
        builder: (context) {
          capture(context.read<_CounterCubit>());
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

void main() {
  testWidgets('a session key change disposes the blocs and creates new ones', (tester) async {
    // The bug this guards: every bloc lived at the app root, above the auth
    // gate, so StoreBloc.selectedStore survived logout and the next session
    // fetched against the previous user's store — a 403 that surfaced as
    // "Недостаточно прав" on every screen.
    final seen = <_CounterCubit>[];

    await tester.pumpWidget(_subtree('user-1', seen.add));
    seen.last.bump();
    expect(seen.last.state, 1);

    await tester.pumpWidget(_subtree('user-2', seen.add));
    await tester.pump();

    expect(seen.length, greaterThanOrEqualTo(2));
    expect(identical(seen.first, seen.last), isFalse,
        reason: 'a new session must get a new bloc instance');
    expect(seen.last.state, 0, reason: 'state must not carry over');
  });

  testWidgets('the same session key keeps the same bloc instance', (tester) async {
    // The other half, and the one that matters most: MaterialApp's builder
    // runs on every route build, so the keyed provider must be STABLE across
    // navigation. If this fails, blocs are recreated on every navigation —
    // worse than the bug being fixed.
    final seen = <_CounterCubit>[];

    await tester.pumpWidget(_subtree('user-1', seen.add));
    seen.last.bump();
    await tester.pumpWidget(_subtree('user-1', seen.add));
    await tester.pump();

    expect(identical(seen.first, seen.last), isTrue,
        reason: 'same key must reuse the element, not rebuild the bloc');
    expect(seen.last.state, 1, reason: 'state must survive a rebuild');
  });

  testWidgets('a store change also disposes the store-scoped blocs', (tester) async {
    // Switching stores refreshed nothing: dashboard, Товары and Финансы all
    // kept the previous store's data, and the API log showed only a
    // banners/active request for the newly selected store.
    final seen = <_CounterCubit>[];

    Widget tree(String session, String store) => MaterialApp(
          home: MultiBlocProvider(
            key: ValueKey('$session|$store'),
            providers: [BlocProvider(create: (_) => _CounterCubit())],
            child: Builder(builder: (context) {
              seen.add(context.read<_CounterCubit>());
              return const SizedBox.shrink();
            }),
          ),
        );

    await tester.pumpWidget(tree('user-1', 'store-A'));
    seen.last.bump();
    await tester.pumpWidget(tree('user-1', 'store-B'));
    await tester.pump();

    expect(identical(seen.first, seen.last), isFalse,
        reason: 'a different store must get fresh blocs');
    expect(seen.last.state, 0, reason: 'the previous store\'s state must not carry over');
  });

  group('StoreScope', () {
    // The bloc and its fake are built INSIDE each test body on purpose: a bloc
    // created in setUp lives outside testWidgets' fake-async zone, so its
    // awaits never resume when the test pumps.

    testWidgets('should keep the store key when the bloc goes back to '
        'StoreLoading for a list reload', (tester) async {
      final h = await _StoreScopeHarness.pump(tester);
      await h.selectFirstStore(tester, 'A');
      expect(h.keys.last, 'store:A');

      // my_stores_page / home_page re-dispatch StoreLoadRequested, which emits
      // StoreLoading first. Hold the repository open so we observe that state.
      final pending = Completer<List<Store>>();
      // Release it in teardown too: if an expectation below fails, an
      // uncompleted future would leave the event handler in flight and
      // `bloc.close()` would hang instead of the test reporting failure.
      addTearDown(() async {
        if (!pending.isCompleted) pending.complete(const []);
        await tester.pumpAndSettle();
      });
      h.repository.stores = () => pending.future;
      h.bloc.add(StoreLoadRequested());
      // Two pumps: the first delivers the event, the second lets any listener
      // of the bloc rebuild. With one, a key recomputed from the live state
      // had not been rebuilt yet and this test passed against the bug.
      await tester.pump();
      await tester.pump();

      expect(h.bloc.state, isA<StoreLoading>(),
          reason: 'the reload really has to pass through StoreLoading');
      expect(h.keys.last, 'store:A',
          reason: 'a transient StoreLoading must not tear down the '
              'store-scoped blocs');

      pending.complete([_store('A')]);
      await tester.pumpAndSettle();
      expect(h.keys.last, 'store:A');
    });

    testWidgets('should keep the store key when the bloc emits StoreError',
        (tester) async {
      final h = await _StoreScopeHarness.pump(tester);
      await h.selectFirstStore(tester, 'A');

      h.repository.stores = () async => throw Exception('offline');
      h.bloc.add(StoreLoadRequested());
      await tester.pumpAndSettle();

      expect(h.bloc.state, isA<StoreError>());
      expect(h.keys.last, 'store:A',
          reason: 'a failed reload must leave the screens mounted, not blank');
    });

    testWidgets('should keep the store key when the parent rebuilds while the '
        'bloc is in a transient state', (tester) async {
      // MaterialApp.builder runs on every route build, so the key must not be
      // recomputed from whatever state the bloc happens to be in right now.
      late StateSetter rebuildParent;
      final h = await _StoreScopeHarness.pump(
        tester,
        wrap: (child) => StatefulBuilder(
          builder: (context, setState) {
            rebuildParent = setState;
            return child;
          },
        ),
      );
      await h.selectFirstStore(tester, 'A');

      final pending = Completer<List<Store>>();
      // Release it in teardown too: if an expectation below fails, an
      // uncompleted future would leave the event handler in flight and
      // `bloc.close()` would hang instead of the test reporting failure.
      addTearDown(() async {
        if (!pending.isCompleted) pending.complete(const []);
        await tester.pumpAndSettle();
      });
      h.repository.stores = () => pending.future;
      h.bloc.add(StoreLoadRequested());
      await tester.pump();
      await tester.pump();

      rebuildParent(() {});
      await tester.pump();

      expect(h.keys.last, 'store:A');

      pending.complete([_store('A')]);
      await tester.pumpAndSettle();
    });

    testWidgets('should change the store key when a different store becomes '
        'the selection', (tester) async {
      final h = await _StoreScopeHarness.pump(tester);
      await h.selectFirstStore(tester, 'A');
      expect(h.keys.last, 'store:A');

      await h.selectFirstStore(tester, 'B');
      expect(h.keys.last, 'store:B',
          reason: 'a real store switch must still refresh the scoped blocs');
    });

    testWidgets('should report no store when the scope is recreated for a new '
        'session', (tester) async {
      // app.dart puts StoreScope INSIDE the session-keyed subtree, so logging
      // in as a different account rebuilds it from scratch. The retained id
      // must not survive that — the bug fixed in 2082dc8.
      final keys = <String>[];
      Widget session(String sessionKey, StoreBloc sessionBloc) => MaterialApp(
            home: MultiBlocProvider(
              key: ValueKey('session:$sessionKey'),
              providers: [BlocProvider<StoreBloc>.value(value: sessionBloc)],
              child: StoreScope(
                builder: (context, storeKey) {
                  keys.add(storeKey);
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

      final repository = _FakeStoreRepository();
      final bloc = StoreBloc(storeRepository: repository);
      addTearDown(bloc.close);
      await tester.pumpWidget(session('user-1', bloc));

      repository.stores = () async => [_store('A')];
      bloc.add(StoreLoadRequested());
      await tester.pumpAndSettle();
      expect(keys.last, 'store:A');

      final nextBloc = StoreBloc(storeRepository: _FakeStoreRepository());
      addTearDown(nextBloc.close);
      await tester.pumpWidget(session('user-2', nextBloc));
      await tester.pump();

      expect(keys.last, 'no-store',
          reason: "the previous account's store must not be retained");
    });
  });
}

Store _store(String id) => Store(
      id: id,
      ownerId: 'owner-1',
      name: 'Shop $id',
      category: 'grocery',
      createdAt: DateTime(2026, 1, 1),
    );

/// Mirrors app.dart's level 2: StoreBloc above, StoreScope as its child, the
/// derived key feeding a keyed provider below.
class _StoreScopeHarness {
  _StoreScopeHarness(this.repository, this.bloc);

  final _FakeStoreRepository repository;
  final StoreBloc bloc;
  final List<String> keys = <String>[];

  static Future<_StoreScopeHarness> pump(
    WidgetTester tester, {
    Widget Function(Widget child)? wrap,
  }) async {
    final repository = _FakeStoreRepository();
    final bloc = StoreBloc(storeRepository: repository);
    addTearDown(bloc.close);
    final harness = _StoreScopeHarness(repository, bloc);

    Widget scope = StoreScope(
      builder: (context, storeKey) {
        harness.keys.add(storeKey);
        return const SizedBox.shrink();
      },
    );
    if (wrap != null) scope = wrap(scope);

    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<StoreBloc>.value(value: bloc, child: scope),
    ));
    return harness;
  }

  Future<void> selectFirstStore(WidgetTester tester, String id) async {
    repository.stores = () async => [_store(id)];
    bloc.add(StoreLoadRequested());
    await tester.pumpAndSettle();
  }
}

/// Hand-rolled fake so a test can hold `getStores()` open and observe the
/// StoreLoading state a real reload passes through.
class _FakeStoreRepository implements StoreRepository {
  Future<List<Store>> Function() stores = () async => const [];

  @override
  Future<List<Store>> getStores() => stores();

  @override
  Future<Store> createStore({
    required String name,
    required String category,
    String currency = 'TJS',
    String? address,
    String? phone,
  }) =>
      throw UnimplementedError();

  @override
  Future<Store> getStore(String id) => throw UnimplementedError();

  @override
  Future<Store> updateStore(String id, Map<String, dynamic> data) =>
      throw UnimplementedError();

  @override
  Future<void> deleteStore(String id) => throw UnimplementedError();
}
