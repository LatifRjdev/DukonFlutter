import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dukonpro/domain/repositories/loyalty_repository.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_settings_bloc.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_settings_event.dart';
import 'package:dukonpro/presentation/blocs/loyalty/loyalty_settings_state.dart';

class MockLoyaltyRepository extends Mock implements LoyaltyRepository {}

void main() {
  late MockLoyaltyRepository repo;

  final mockSettings = <String, dynamic>{
    'storeId': 'store-1',
    'isEnabled': true,
    'pointsPerAmount': 1,
    'amountForPoints': '100',
    'pointValue': '0.01',
    'welcomePoints': 50,
    'birthdayDiscount': null,
    'pointsExpireDays': null,
  };

  setUp(() {
    repo = MockLoyaltyRepository();
  });

  group('LoyaltySettingsBloc', () {
    blocTest<LoyaltySettingsBloc, LoyaltySettingsState>(
      'should emit [Loading, Loaded] when settings are fetched successfully',
      build: () {
        when(() => repo.getSettings(any())).thenAnswer((_) async => mockSettings);
        return LoyaltySettingsBloc(repository: repo);
      },
      act: (bloc) => bloc.add(const LoyaltySettingsLoadRequested('store-1')),
      expect: () => [
        isA<LoyaltySettingsLoading>(),
        isA<LoyaltySettingsLoaded>()
            .having((s) => s.settings['isEnabled'], 'isEnabled', true)
            .having((s) => s.settings['welcomePoints'], 'welcomePoints', 50),
      ],
    );

    blocTest<LoyaltySettingsBloc, LoyaltySettingsState>(
      'should emit [Loading, Saved] when save succeeds',
      build: () {
        when(() => repo.updateSettings(any(), any()))
            .thenAnswer((_) async => {...mockSettings, 'isEnabled': false});
        return LoyaltySettingsBloc(repository: repo);
      },
      act: (bloc) => bloc.add(
        LoyaltySettingsSaveRequested('store-1', {'isEnabled': false}),
      ),
      expect: () => [
        isA<LoyaltySettingsLoading>(),
        isA<LoyaltySettingsSaved>()
            .having((s) => s.settings['isEnabled'], 'isEnabled', false),
      ],
    );

    blocTest<LoyaltySettingsBloc, LoyaltySettingsState>(
      'should emit [Loading, Error] when fetch fails',
      build: () {
        when(() => repo.getSettings(any()))
            .thenThrow(Exception('Network error'));
        return LoyaltySettingsBloc(repository: repo);
      },
      act: (bloc) => bloc.add(const LoyaltySettingsLoadRequested('store-1')),
      expect: () => [
        isA<LoyaltySettingsLoading>(),
        isA<LoyaltySettingsError>(),
      ],
    );
  });
}
