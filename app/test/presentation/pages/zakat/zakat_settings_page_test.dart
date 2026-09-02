// Regression coverage for SPEC.md #19 — the "reminder enabled" and
// "include supplier debts" toggles updated local UI state via setState,
// but _save()'s payload to ZakatSettingsUpdated never included them, so
// toggling either switch and tapping Save silently lost the change. A
// backend-integrated fix is out of scope for this plan (the backend's
// ZakatSettings model/DTO don't declare these fields, and the API's
// forbidNonWhitelisted validation pipe would reject the whole save
// request if they were added to the payload). Instead, these two fields
// are persisted client-side to SharedPreferences and read back on load —
// this closes the literal "change is lost" bug without touching the
// backend contract. These tests prove: (a) toggling either switch and
// saving writes the new value locally, and (b) reopening the page (a
// fresh widget instance) restores the previously-saved value instead of
// always resetting to the hardcoded default.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/zakat_settings.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_bloc.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_event.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_state.dart';
import 'package:dukonpro/presentation/pages/zakat/zakat_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fixtures/mock_blocs.dart';

class MockZakatBloc extends MockBloc<ZakatEvent, ZakatState>
    implements ZakatBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockZakatBloc zakatBloc;

  const storeId = 'store-1';

  final loadedSettings = ZakatSettings(
    id: 'zs-1',
    storeId: storeId,
    nisabAmount: 78200,
    cashOnHand: 1000,
    includeStock: true,
    includeCash: true,
    includeDebts: true,
    haulStartDate: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(
      const ZakatSettingsUpdated(storeId: storeId, data: {}),
    );
  });

  setUp(() {
    storeBloc = MockStoreBloc();
    zakatBloc = MockZakatBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
  });

  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<StoreBloc>.value(value: storeBloc),
            BlocProvider<ZakatBloc>.value(value: zakatBloc),
          ],
          child: child,
        ),
      );

  group('ZakatSettingsPage local persistence (SPEC.md #19)', () {
    testWidgets(
        'toggling the reminder and supplier-debts switches then tapping '
        'Save writes the new values to SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final stateController = StreamController<ZakatState>.broadcast();
      addTearDown(stateController.close);
      whenListen<ZakatState>(
        zakatBloc,
        stateController.stream,
        initialState: ZakatLoading(),
      );

      // Tall surface so the full ListView (all 5 switches + save button)
      // is laid out without needing to scroll to find widgets.
      await tester.binding.setSurfaceSize(const Size(412, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(const ZakatSettingsPage(storeId: storeId)));
      await tester.pump();

      // Deliver the settings load the real bloc would emit after
      // ZakatSettingsRequested — this is what populates the gold-price
      // field so the form can validate, and marks the page initialized.
      stateController.add(ZakatSettingsLoaded(loadedSettings));
      await tester.pump();

      final switches = find.byType(Switch);
      // Order matches build order: reminder switch (haul section) comes
      // before the four auto-data toggle rows, the last of which is
      // "include supplier debts".
      final reminderSwitch = switches.at(0);
      final supplierDebtsSwitch = switches.at(4);

      expect(tester.widget<Switch>(reminderSwitch).value, isTrue);
      expect(tester.widget<Switch>(supplierDebtsSwitch).value, isTrue);

      await tester.tap(reminderSwitch);
      await tester.pump();
      await tester.tap(supplierDebtsSwitch);
      await tester.pump();

      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      // Let the fire-and-forget SharedPreferences write inside _save()
      // complete.
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('zakat_reminder_enabled'), isFalse);
      expect(prefs.getBool('zakat_include_supplier_debts'), isFalse);

      // The existing backend-facing fields must still go out unchanged,
      // and the payload must NOT contain the two local-only fields
      // (adding them would trip the backend's forbidNonWhitelisted
      // validation and break every save).
      final captured = verify(() => zakatBloc.add(captureAny(
            that: isA<ZakatSettingsUpdated>(),
          ))).captured;
      expect(captured, hasLength(1));
      final event = captured.single as ZakatSettingsUpdated;
      expect(event.data.containsKey('reminderEnabled'), isFalse);
      expect(event.data.containsKey('includeSupplierDebts'), isFalse);
      expect(event.data['includeStock'], isTrue);
      expect(event.data['includeCash'], isTrue);
      expect(event.data['includeDebts'], isTrue);
      expect(event.data['cashOnHand'], 1000.0);
    });

    testWidgets(
        'reopening the page (a fresh widget instance) reads back '
        'previously-saved local values instead of resetting to the '
        'hardcoded default', (tester) async {
      SharedPreferences.setMockInitialValues({
        'zakat_reminder_enabled': false,
        'zakat_include_supplier_debts': false,
      });

      final freshBloc = MockZakatBloc();
      final stateController = StreamController<ZakatState>.broadcast();
      addTearDown(stateController.close);
      whenListen<ZakatState>(
        freshBloc,
        stateController.stream,
        initialState: ZakatLoading(),
      );

      await tester.binding.setSurfaceSize(const Size(412, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: MultiBlocProvider(
            providers: [
              BlocProvider<StoreBloc>.value(value: storeBloc),
              BlocProvider<ZakatBloc>.value(value: freshBloc),
            ],
            child: const ZakatSettingsPage(storeId: storeId),
          ),
        ),
      );
      // Two pumps: one for the widget tree, one to let the async
      // SharedPreferences.getInstance() read in _loadLocalPreferences()
      // resolve and setState.
      await tester.pump();
      await tester.pump();

      stateController.add(ZakatSettingsLoaded(loadedSettings));
      await tester.pump();

      final switches = find.byType(Switch);
      final reminderSwitch = switches.at(0);
      final supplierDebtsSwitch = switches.at(4);

      expect(tester.widget<Switch>(reminderSwitch).value, isFalse);
      expect(tester.widget<Switch>(supplierDebtsSwitch).value, isFalse);
    });
  });

  group('ZakatSettingsPage gold-price refresh (SPEC.md #38)', () {
    // The real ZakatBloc always emits ZakatLoading() before the eventual
    // ZakatSettingsLoaded/ZakatError (see ZakatBloc._onSettingsRequested) —
    // including on the refresh path, since refresh just re-dispatches
    // ZakatSettingsRequested. An earlier version of this fix reset the
    // shared _initialized flag on refresh, which made that intermediate
    // ZakatLoading() satisfy the builder's `state is ZakatLoading &&
    // !_initialized` guard too, tearing down the whole form into a bare
    // spinner on every refresh tap, and made the listener's blanket
    // field-overwrite re-run on every refresh, silently discarding any
    // unsaved edits to fields other than gold price. These tests exercise
    // the REAL bloc sequence (including the intermediate ZakatLoading) and
    // prove neither regression is present: the form stays mounted through
    // a refresh, and refreshing gold price alone doesn't touch other
    // fields' in-progress edits.
    testWidgets(
        'tapping the refresh button applies a freshly-fetched gold price '
        'to the visible field, without a full-page spinner replacing the '
        'form for the intermediate ZakatLoading state', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final stateController = StreamController<ZakatState>.broadcast();
      addTearDown(stateController.close);
      whenListen<ZakatState>(
        zakatBloc,
        stateController.stream,
        initialState: ZakatLoading(),
      );

      await tester.binding.setSurfaceSize(const Size(412, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(const ZakatSettingsPage(storeId: storeId)));
      await tester.pump();

      // Initial load: nisabAmount 78200 -> gold price field shows
      // (78200 / 85).toStringAsFixed(2) == '920.00'.
      stateController.add(ZakatSettingsLoaded(loadedSettings));
      await tester.pump();

      // Gold price is the first TextFormField built (cash-on-hand is the
      // second), per the widget build order in zakat_settings_page.dart.
      final goldPriceField = find.byType(TextFormField).first;
      expect(
        tester.widget<TextFormField>(goldPriceField).controller!.text,
        '920.00',
      );

      // There is exactly one refresh icon on the page (the gold-price
      // card's refresh button).
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // The real bloc's intermediate state, emitted before it fetches the
      // fresh settings. The form must stay mounted through this — no
      // full-page spinner replacing it.
      stateController.add(ZakatLoading());
      await tester.pump();
      expect(find.byType(TextFormField), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Simulate the bloc emitting a new ZakatSettingsLoaded after the
      // refresh's ZakatSettingsRequested completes, this time with a
      // different (freshly-fetched) nisabAmount.
      final refreshedSettings = ZakatSettings(
        id: 'zs-1',
        storeId: storeId,
        nisabAmount: 85000,
        cashOnHand: 1000,
        includeStock: true,
        includeCash: true,
        includeDebts: true,
        haulStartDate: DateTime(2026, 1, 1),
      );
      stateController.add(ZakatSettingsLoaded(refreshedSettings));
      await tester.pump();

      // (85000 / 85).toStringAsFixed(2) == '1000.00'. Before the original
      // #38 fix, the !_initialized guard silently dropped this reload and
      // the field stayed at '920.00'.
      expect(
        tester.widget<TextFormField>(goldPriceField).controller!.text,
        '1000.00',
      );
    });

    testWidgets(
        'refreshing the gold price does not discard an unsaved edit to '
        'the cash-on-hand field', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final stateController = StreamController<ZakatState>.broadcast();
      addTearDown(stateController.close);
      whenListen<ZakatState>(
        zakatBloc,
        stateController.stream,
        initialState: ZakatLoading(),
      );

      await tester.binding.setSurfaceSize(const Size(412, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(const ZakatSettingsPage(storeId: storeId)));
      await tester.pump();

      // loadedSettings.cashOnHand == 1000.
      stateController.add(ZakatSettingsLoaded(loadedSettings));
      await tester.pump();

      final cashOnHandField = find.byType(TextFormField).at(1);
      expect(
        tester.widget<TextFormField>(cashOnHandField).controller!.text,
        '1000.0',
      );

      // User starts editing cash-on-hand but hasn't saved yet.
      await tester.enterText(cashOnHandField, '5000');
      await tester.pump();
      expect(
        tester.widget<TextFormField>(cashOnHandField).controller!.text,
        '5000',
      );

      // Refresh the gold price — the server's cashOnHand (still 1000, no
      // real server-side change) must NOT overwrite the user's in-progress
      // '5000' edit, since this button is scoped to gold price only.
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      stateController.add(ZakatLoading());
      await tester.pump();
      final refreshedSettings = ZakatSettings(
        id: 'zs-1',
        storeId: storeId,
        nisabAmount: 85000,
        cashOnHand: 1000,
        includeStock: true,
        includeCash: true,
        includeDebts: true,
        haulStartDate: DateTime(2026, 1, 1),
      );
      stateController.add(ZakatSettingsLoaded(refreshedSettings));
      await tester.pump();

      expect(
        tester.widget<TextFormField>(cashOnHandField).controller!.text,
        '5000',
      );
      // Gold price itself still updates, per the other test above.
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '1000.00',
      );
    });
  });
}
