import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/store.dart';
import 'package:dukonpro/domain/entities/user.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_bloc.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_event.dart';
import 'package:dukonpro/presentation/blocs/settings/settings_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/store/store_event.dart';
import 'package:dukonpro/presentation/blocs/store/store_state.dart';
import 'package:dukonpro/presentation/pages/settings/edit_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _MockStoreBloc extends MockBloc<StoreEvent, StoreState>
    implements StoreBloc {}

User _fakeUser() => User(
      id: 'test-user-id',
      phone: '+992900000000',
      name: 'Test User',
      email: 'test@example.com',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    );

Store _fakeStore({required String ownerId}) => Store(
      id: 'store-1',
      ownerId: ownerId,
      name: 'Test Store',
      category: 'retail',
      currency: 'TJS',
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  late _MockSettingsBloc settingsBloc;
  late _MockStoreBloc storeBloc;

  setUp(() {
    settingsBloc = _MockSettingsBloc();
    storeBloc = _MockStoreBloc();
    final user = _fakeUser();
    final loaded = SettingsLoaded(user);
    // The role badge (SPEC.md audit finding #5) is resolved from a
    // BlocConsumer.listener reacting to a *stream* emission of
    // SettingsLoaded, not merely the bloc's already-current `.state`
    // (BlocListener never fires for a state that was already current when
    // the widget mounted) — mirrors settings_page_test.dart's setup for the
    // same underlying pattern.
    whenListen<SettingsState>(
      settingsBloc,
      Stream.value(loaded),
      initialState: loaded,
    );
    // Test user owns the store, so the role resolves via the ownerId
    // shortcut (no StaffRepository lookup needed) to the same "Владелец"
    // label the old hardcoded text showed — keeping this golden's visual
    // output meaningful while now being driven by real data.
    when(() => storeBloc.state).thenReturn(
      StoreLoaded(
        stores: [_fakeStore(ownerId: user.id)],
        selectedStore: _fakeStore(ownerId: user.id),
      ),
    );
  });

  tearDown(() {
    settingsBloc.close();
    storeBloc.close();
  });

  Widget page() => const EditProfilePage();

  Widget wrapWithBloc(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<StoreBloc>.value(value: storeBloc),
        ],
        child: child,
      );

  group('EditProfilePage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBloc,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'edit_profile_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBloc,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'edit_profile_dark');
    });
  });
}
