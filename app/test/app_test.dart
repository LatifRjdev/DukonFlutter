import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/presentation/blocs/settings/settings_bloc.dart';
import 'package:dokonpro/presentation/blocs/settings/settings_event.dart';
import 'package:dokonpro/presentation/blocs/settings/settings_state.dart';
import 'package:dokonpro/domain/entities/user.dart';

class MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _FakeEvent extends Fake implements SettingsEvent {}

/// Harness mirrors the wiring we'll add inside DokonProApp.build().
Widget _underTest(SettingsBloc bloc) {
  return BlocProvider<SettingsBloc>.value(
    value: bloc,
    child: BlocBuilder<SettingsBloc, SettingsState>(
      buildWhen: (prev, curr) {
        if (curr is! SettingsLoaded) return false;
        final prevTheme = prev is SettingsLoaded ? prev.themeMode : null;
        return prevTheme != curr.themeMode;
      },
      builder: (context, state) {
        final themeMode =
            state is SettingsLoaded ? state.themeMode : ThemeMode.system;
        return MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          home: const Scaffold(body: Text('home')),
        );
      },
    ),
  );
}

User _dummyUser() {
  return User(
    id: 'id',
    phone: '+9920000',
    name: 'T',
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group('App theme wiring', () {
    late MockSettingsBloc bloc;

    setUp(() {
      bloc = MockSettingsBloc();
    });

    testWidgets('defaults to system when state is not SettingsLoaded',
        (tester) async {
      when(() => bloc.state).thenReturn(SettingsInitial());
      whenListen(bloc, Stream<SettingsState>.fromIterable([SettingsInitial()]),
          initialState: SettingsInitial());

      await tester.pumpWidget(_underTest(bloc));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
    });

    testWidgets('uses dark when SettingsLoaded emits themeMode=dark',
        (tester) async {
      final loaded = SettingsLoaded(_dummyUser(), themeMode: ThemeMode.dark);
      when(() => bloc.state).thenReturn(loaded);
      whenListen(bloc, Stream<SettingsState>.fromIterable([loaded]),
          initialState: loaded);

      await tester.pumpWidget(_underTest(bloc));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });

    testWidgets('uses light when SettingsLoaded emits themeMode=light',
        (tester) async {
      final loaded = SettingsLoaded(_dummyUser(), themeMode: ThemeMode.light);
      when(() => bloc.state).thenReturn(loaded);
      whenListen(bloc, Stream<SettingsState>.fromIterable([loaded]),
          initialState: loaded);

      await tester.pumpWidget(_underTest(bloc));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
    });

    // Regression: transient states (Loading, ActionSuccess) between two
    // SettingsLoaded values must not rebuild MaterialApp. Previously this
    // caused navigation to reset to splash on every theme toggle.
    testWidgets('keeps previous theme across transient SettingsActionSuccess',
        (tester) async {
      final loaded = SettingsLoaded(_dummyUser(), themeMode: ThemeMode.dark);
      when(() => bloc.state).thenReturn(loaded);
      whenListen(
        bloc,
        Stream<SettingsState>.fromIterable([
          loaded,
          const SettingsActionSuccess('Профиль обновлён'),
          loaded,
        ]),
        initialState: loaded,
      );

      await tester.pumpWidget(_underTest(bloc));
      await tester.pump();
      await tester.pump();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });
}
