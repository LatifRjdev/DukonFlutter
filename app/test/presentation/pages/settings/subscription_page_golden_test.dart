import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/l10n/app_localizations.dart';
import 'package:dokonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dokonpro/presentation/blocs/subscription/subscription_bloc.dart';
import 'package:dokonpro/presentation/blocs/subscription/subscription_event.dart';
import 'package:dokonpro/presentation/blocs/subscription/subscription_state.dart';
import 'package:dokonpro/presentation/pages/settings/subscription_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class _MockSubscriptionBloc
    extends MockBloc<SubscriptionEvent, SubscriptionState>
    implements SubscriptionBloc {}

SubscriptionLoaded _fakeLoaded() => SubscriptionLoaded(
      plan: 'BUSINESS',
      status: 'ACTIVE',
      expiresAt: DateTime(2026, 3, 30),
      limits: const SubscriptionLimits(
        maxStores: 3,
        maxProducts: 2000,
        maxStaff: 10,
        maxDiscounts: 5,
      ),
      features: const SubscriptionFeatures(
        hasReportsAll: true,
        hasExport: false,
        hasTelegram: true,
        hasAllPush: false,
        hasDelivery: true,
        hasInventory: true,
      ),
      payments: const [],
    );

Future<void> _pumpPage(
  WidgetTester tester,
  Brightness brightness,
  _MockSubscriptionBloc subscriptionBloc,
  MockStoreBloc storeBloc,
) async {
  await tester.binding.setSurfaceSize(const Size(412, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SubscriptionBloc>.value(value: subscriptionBloc),
          BlocProvider<StoreBloc>.value(value: storeBloc),
        ],
        child: const SubscriptionPage(),
      ),
    ),
  );
  // Pump two frames — avoids pumpAndSettle timeout from RefreshIndicator
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  late _MockSubscriptionBloc subscriptionBloc;
  late MockStoreBloc storeBloc;

  setUp(() {
    subscriptionBloc = _MockSubscriptionBloc();
    storeBloc = MockStoreBloc();

    when(() => subscriptionBloc.state).thenReturn(_fakeLoaded());
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
  });

  tearDown(() {
    subscriptionBloc.close();
    storeBloc.close();
  });

  group('SubscriptionPage goldens', () {
    testWidgets('light theme', (tester) async {
      await _pumpPage(tester, Brightness.light, subscriptionBloc, storeBloc);
      tester.takeException();
      await expectLater(
        find.byType(SubscriptionPage),
        matchesGoldenFile('goldens/subscription_light.png'),
      );
    });

    testWidgets('dark theme', (tester) async {
      await _pumpPage(tester, Brightness.dark, subscriptionBloc, storeBloc);
      tester.takeException();
      await expectLater(
        find.byType(SubscriptionPage),
        matchesGoldenFile('goldens/subscription_dark.png'),
      );
    });
  });
}
