// Regression test for post-plan SPEC.md audit finding #5: EditProfilePage
// hardcoded the role badge to "Владелец" (const Text) regardless of the
// actual logged-in user's role. This exercises the fix (mirroring
// SettingsPage's already-fixed #13 role-badge pattern): role is resolved
// from StoreBloc (ownerId match), falling back to a StaffRepository lookup,
// and the badge is hidden rather than ever showing an incorrect role.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/staff_member.dart';
import 'package:dukonpro/domain/entities/store.dart';
import 'package:dukonpro/domain/entities/user.dart';
import 'package:dukonpro/domain/repositories/staff_repository.dart';
import 'package:dukonpro/injection.dart';
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
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _MockStoreBloc extends MockBloc<StoreEvent, StoreState>
    implements StoreBloc {}

class _MockStaffRepository extends Mock implements StaffRepository {}

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

  final user = _fakeUser();

  setUp(() {
    settingsBloc = _MockSettingsBloc();
    storeBloc = _MockStoreBloc();
    final loaded = SettingsLoaded(user);
    whenListen<SettingsState>(
      settingsBloc,
      Stream.value(loaded),
      initialState: loaded,
    );
  });

  tearDown(() {
    settingsBloc.close();
    storeBloc.close();
    if (sl.isRegistered<StaffRepository>()) {
      sl.unregister<StaffRepository>();
    }
  });

  Widget page() => const EditProfilePage();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<StoreBloc>.value(value: storeBloc),
        ],
        child: child,
      );

  Future<void> pump(WidgetTester tester) => pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );

  group('EditProfilePage — role badge (SPEC.md audit finding #5)', () {
    testWidgets('shows the real owner label when the user owns the store',
        (tester) async {
      when(() => storeBloc.state).thenReturn(
        StoreLoaded(
          stores: [_fakeStore(ownerId: user.id)],
          selectedStore: _fakeStore(ownerId: user.id),
        ),
      );

      await pump(tester);

      expect(find.text('Владелец'), findsOneWidget);
    });

    testWidgets('shows the real cashier label for a non-owner staff member',
        (tester) async {
      when(() => storeBloc.state).thenReturn(
        StoreLoaded(
          stores: [_fakeStore(ownerId: 'someone-else')],
          selectedStore: _fakeStore(ownerId: 'someone-else'),
        ),
      );
      final staffRepo = _MockStaffRepository();
      when(() => staffRepo.getStaff('store-1')).thenAnswer(
        (_) async => (
          data: [
            StaffMember(
              id: 'staff-1',
              storeId: 'store-1',
              userId: user.id,
              name: user.name,
              phone: user.phone,
              role: 'CASHIER',
              createdAt: DateTime(2024, 1, 1),
            ),
          ],
          total: 1,
          totalPages: 1,
        ),
      );
      sl.registerSingleton<StaffRepository>(staffRepo);

      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Кассир'), findsOneWidget);
      expect(find.text('Владелец'), findsNothing);
    });

    testWidgets(
        'hides the badge instead of falsely showing the old hardcoded '
        'owner label for a non-owner whose role cannot be resolved',
        (tester) async {
      // Current user is NOT the store owner, and no StaffRepository is
      // registered in this test's service locator, so the staff-lookup
      // fallback can't resolve a role either. The old implementation always
      // rendered "Владелец" regardless — this proves the badge is now
      // driven by real data, not a hardcoded string.
      when(() => storeBloc.state).thenReturn(
        StoreLoaded(
          stores: [_fakeStore(ownerId: 'someone-else')],
          selectedStore: _fakeStore(ownerId: 'someone-else'),
        ),
      );

      await pump(tester);

      expect(find.text('Владелец'), findsNothing);
    });
  });
}
