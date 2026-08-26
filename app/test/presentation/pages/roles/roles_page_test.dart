// Regression coverage for SPEC.md #4: toggling a permission switch on the
// Roles page only dispatched UpdatePermission (in-memory bloc state), never
// SavePermissions (which actually persists to the server) — so changes were
// silently lost the moment the user navigated away and back. This test
// exercises the fix: a Save action that reads the role's current permissions
// off the bloc state and dispatches SavePermissions with them.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/role_permission.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/roles/roles_bloc.dart';
import 'package:dukonpro/presentation/blocs/roles/roles_event.dart';
import 'package:dukonpro/presentation/blocs/roles/roles_state.dart';
import 'package:dukonpro/presentation/pages/roles/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRolesBloc extends MockBloc<RolesEvent, RolesState>
    implements RolesBloc {}

void main() {
  late _MockRolesBloc rolesBloc;
  late StreamController<RolesState> stateController;

  const ownerRole = RolePermission(role: 'OWNER', permissions: {});

  const cashierPermissionsOff = <String, bool>{
    'manage_products': false,
    'manage_sales': true,
    'manage_returns': false,
    'view_reports': false,
    'manage_staff': false,
    'manage_expenses': false,
    'manage_customers': false,
    'manage_suppliers': false,
    'manage_stock': false,
    'manage_debts': false,
    'manage_settings': false,
    'open_close_shift': false,
    'apply_discounts': false,
    'manage_payroll': false,
  };

  final cashierPermissionsToggled = <String, bool>{
    ...cashierPermissionsOff,
    'manage_products': true,
  };

  const cashierRoleInitial = RolePermission(
    role: 'CASHIER',
    permissions: cashierPermissionsOff,
  );
  final cashierRoleToggled = RolePermission(
    role: 'CASHIER',
    permissions: cashierPermissionsToggled,
  );

  setUpAll(() {
    registerFallbackValue(const LoadRoles(storeId: ''));
  });

  setUp(() {
    rolesBloc = _MockRolesBloc();
    stateController = StreamController<RolesState>.broadcast();
  });

  tearDown(() async {
    await stateController.close();
    await rolesBloc.close();
  });

  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<RolesBloc>.value(value: rolesBloc, child: child),
      );

  testWidgets(
      'toggling a permission then tapping Save dispatches SavePermissions '
      'with the toggled value (SPEC.md #4)', (tester) async {
    const loaded = RolesLoaded(roles: [cashierRoleInitial, ownerRole]);
    whenListen<RolesState>(
      rolesBloc,
      stateController.stream,
      initialState: loaded,
    );

    await tester.pumpWidget(wrap(const RolesPage(storeId: 'store-1')));
    await tester.pumpAndSettle();

    // Switch to the CASHIER tab (OWNER is selected by default and its
    // permissions are locked, so it has no Save action to test).
    await tester.tap(find.text('Кассир'));
    await tester.pumpAndSettle();

    // The Save button must be enabled for an editable role, and start out
    // showing the "Сохранить" label (not mid-save).
    final saveButtonFinder = find.byKey(const Key('roles_save_button'));
    expect(saveButtonFinder, findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(saveButtonFinder).onPressed,
      isNotNull,
    );

    // manage_products starts off for CASHIER — its switch should read false.
    final firstSwitch = tester.widget<Switch>(find.byType(Switch).first);
    expect(firstSwitch.value, isFalse);

    // Toggle it on. This must still dispatch UpdatePermission (existing,
    // already-working in-memory update) exactly as before the fix.
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    final updateCaptured = verify(() => rolesBloc.add(captureAny(
          that: isA<UpdatePermission>(),
        ))).captured;
    expect(updateCaptured, hasLength(1));
    final updateEvent = updateCaptured.single as UpdatePermission;
    expect(updateEvent.storeId, 'store-1');
    expect(updateEvent.role, 'CASHIER');
    expect(updateEvent.permission, 'manage_products');
    expect(updateEvent.value, isTrue);

    // Simulate the bloc applying that update (what the real RolesBloc's
    // _onUpdatePermission handler does) by emitting the toggled state.
    stateController.add(RolesLoaded(roles: [cashierRoleToggled, ownerRole]));
    await tester.pump();

    // Tapping Save is the crux of the fix: previously nothing on the page
    // ever dispatched SavePermissions, so the toggle above never reached
    // the server and reverted on next load.
    await tester.tap(saveButtonFinder);
    await tester.pump();

    final saveCaptured = verify(() => rolesBloc.add(captureAny(
          that: isA<SavePermissions>(),
        ))).captured;
    expect(saveCaptured, hasLength(1));
    final saveEvent = saveCaptured.single as SavePermissions;
    expect(saveEvent.storeId, 'store-1');
    expect(saveEvent.role, 'CASHIER');
    expect(saveEvent.permissions, cashierPermissionsToggled);
  });

  testWidgets('Save is disabled on the OWNER tab (nothing there can change)',
      (tester) async {
    const loaded = RolesLoaded(roles: [cashierRoleInitial, ownerRole]);
    whenListen<RolesState>(
      rolesBloc,
      stateController.stream,
      initialState: loaded,
    );

    await tester.pumpWidget(wrap(const RolesPage(storeId: 'store-1')));
    await tester.pumpAndSettle();

    // OWNER is the default (first) tab.
    final saveButtonFinder = find.byKey(const Key('roles_save_button'));
    expect(
      tester.widget<ElevatedButton>(saveButtonFinder).onPressed,
      isNull,
    );
  });
}
