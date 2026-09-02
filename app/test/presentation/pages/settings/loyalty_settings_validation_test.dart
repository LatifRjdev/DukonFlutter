// Behavioral coverage for SPEC.md #36 — loyalty settings' numeric fields
// (amount-for-points, points-per-amount, point value, welcome points,
// birthday discount %, points-expire-days) used to parse with
// int.tryParse/double.tryParse and silently substitute null on invalid
// input, so garbage text never blocked Save. These tests prove invalid
// (but non-empty) input now blocks the save request and shows an inline
// error, while a genuinely empty field — which the backend DTO treats as
// "no value" — is still allowed through unchanged.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_settings_bloc.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_settings_event.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_settings_state.dart';
import 'package:dukonpro/presentation/pages/settings/loyalty_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class MockLoyaltySettingsBloc
    extends MockBloc<LoyaltySettingsEvent, LoyaltySettingsState>
    implements LoyaltySettingsBloc {}

void main() {
  late MockLoyaltySettingsBloc bloc;

  final loadedSettings = <String, dynamic>{
    'isEnabled': true,
    'amountForPoints': 100,
    'pointsPerAmount': 1,
    'pointValue': 0.1,
    'welcomePoints': 50,
    'birthdayDiscount': 10,
    'pointsExpireDays': 365,
  };

  setUpAll(() {
    registerFallbackValue(const LoyaltySettingsLoadRequested('store-1'));
  });

  setUp(() {
    bloc = MockLoyaltySettingsBloc();
    final loaded = LoyaltySettingsLoaded(loadedSettings);
    // A BlocConsumer's listener only fires on a *stream* emission, not on
    // the state the widget is already built with — whenListen gives the
    // mock a real stream so _populateControllers actually runs, matching
    // the real bloc's Initial -> Loading -> Loaded transition.
    whenListen<LoyaltySettingsState>(
      bloc,
      Stream.value(loaded),
      initialState: loaded,
    );
  });

  Widget page() => const LoyaltySettingsPage(storeId: 'store-1');

  Widget wrapWithBloc(Widget child) => BlocProvider<LoyaltySettingsBloc>.value(
        value: bloc,
        child: child,
      );

  Future<void> pumpLoaded(WidgetTester tester) async {
    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
      wrap: wrapWithBloc,
    );
  }

  group('LoyaltySettingsPage numeric field validation (SPEC.md #36)', () {
    testWidgets(
        'non-numeric text in a required-format field blocks save and shows an error',
        (tester) async {
      await pumpLoaded(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'За каждые __ сом'),
        'abc',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pump();

      expect(find.text('Неверный формат'), findsOneWidget);
      verifyNever(
        () => bloc.add(any(that: isA<LoyaltySettingsSaveRequested>())),
      );
    });

    testWidgets('a birthday discount over 100% blocks save with a range error',
        (tester) async {
      await pumpLoaded(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Скидка в день рождения, %'),
        '150',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pump();

      expect(find.text('От 0 до 100'), findsOneWidget);
      verifyNever(
        () => bloc.add(any(that: isA<LoyaltySettingsSaveRequested>())),
      );
    });

    testWidgets(
        'an emptied optional field is allowed through as null, not blocked',
        (tester) async {
      await pumpLoaded(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Скидка в день рождения, %'),
        '',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pump();

      expect(find.text('От 0 до 100'), findsNothing);
      expect(find.text('Неверный формат'), findsNothing);
      final captured = verify(
        () => bloc.add(captureAny(that: isA<LoyaltySettingsSaveRequested>())),
      ).captured;
      final event = captured.single as LoyaltySettingsSaveRequested;
      expect(event.data['birthdayDiscount'], isNull);
    });

    testWidgets('valid numeric input for a changed field reaches the save payload',
        (tester) async {
      await pumpLoaded(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Начислять __ баллов'),
        '2',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<LoyaltySettingsSaveRequested>())),
      ).captured;
      final event = captured.single as LoyaltySettingsSaveRequested;
      expect(event.data['pointsPerAmount'], 2.0);
    });
  });
}
