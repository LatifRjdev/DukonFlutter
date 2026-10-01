import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
