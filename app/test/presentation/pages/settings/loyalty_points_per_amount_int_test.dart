// Regression test for post-plan SPEC.md audit finding #4: the backend's
// UpdateLoyaltySettingsDto.pointsPerAmount is @IsInt() @Min(1), but this
// field used _validatePositiveDecimal (a double validator, > 0) and
// double.parse at save time — so a value like "1.5" passed client-side
// validation and was sent as a double, failing the save server-side with a
// 400 the user couldn't make sense of, and even a whole-number entry
// serialized as e.g. `2.0` rather than the `2` the DTO's @IsInt() expects.
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

  group('LoyaltySettingsPage pointsPerAmount is an integer field', () {
    testWidgets('a decimal value blocks save with a format error',
        (tester) async {
      await pumpLoaded(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Начислять __ баллов'),
        '1.5',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pump();

      expect(find.text('Неверный формат'), findsOneWidget);
      verifyNever(
        () => bloc.add(any(that: isA<LoyaltySettingsSaveRequested>())),
      );
    });

    testWidgets('zero blocks save (backend requires Min(1))', (tester) async {
      await pumpLoaded(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Начислять __ баллов'),
        '0',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pump();

      expect(find.text('Некорректное значение'), findsOneWidget);
      verifyNever(
        () => bloc.add(any(that: isA<LoyaltySettingsSaveRequested>())),
      );
    });

    testWidgets(
        'a valid whole number reaches the save payload as an int, not a '
        'double', (tester) async {
      await pumpLoaded(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Начислять __ баллов'),
        '3',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<LoyaltySettingsSaveRequested>())),
      ).captured;
      final event = captured.single as LoyaltySettingsSaveRequested;
      expect(event.data['pointsPerAmount'], isA<int>());
      expect(event.data['pointsPerAmount'], 3);
    });
  });
}
