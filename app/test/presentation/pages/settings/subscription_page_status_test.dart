import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_bloc.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_event.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_state.dart';
import 'package:dukonpro/presentation/pages/settings/subscription_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

// The page's `_statusColor` and `_statusLabel` switch exhaustively over
// SubscriptionStatusKind with no `default`, so the compiler refuses a new enum
// member without a decision. What the compiler CANNOT see is a transposition:
// mapping `pastDue` to `subscriptionExpiredStatus`, or giving it `cancelled`'s
// muted colour, compiles, stays exhaustive, and passes every other test in the
// suite — including the goldens, whose single fixture is ACTIVE.
//
// That is precisely the shape of defect this branch exists to close: the
// replaced receipt tests were green through three real mismatches. So the
// mapping is pinned here, through the real page rather than through the
// mapping function, which `subscription_status_test.dart` already covers.
class _MockSubscriptionBloc
    extends MockBloc<SubscriptionEvent, SubscriptionState>
    implements SubscriptionBloc {}

SubscriptionLoaded _loadedWith(String status) => SubscriptionLoaded(
  plan: 'BUSINESS',
  status: status,
  expiresAt: DateTime(2028, 1, 30),
  limits: const SubscriptionLimits(
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
    hasZakat: false,
    hasInvestments: false,
    hasLoyalty: false,
    hasBatchProfitability: false,
    hasEcommerceIntegration: false,
  ),
  payments: const [],
  availablePlans: const [],
);

void main() {
  late _MockSubscriptionBloc subscriptionBloc;
  late MockStoreBloc storeBloc;

  setUp(() {
    subscriptionBloc = _MockSubscriptionBloc();
    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
  });

  tearDown(() {
    subscriptionBloc.close();
    storeBloc.close();
  });

  Future<void> pumpWithStatus(WidgetTester tester, String status) async {
    when(() => subscriptionBloc.state).thenReturn(_loadedWith(status));

    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Tear the tree down first. A second `pumpWidget` with a structurally
    // identical tree reuses the elements, and the page's `BlocBuilder` rebuilds
    // on stream events — which a MockBloc never emits — so it would keep
    // rendering the PREVIOUS status while `state` already returns the new one.
    // The colour comparison below pumps three statuses in one test and silently
    // compared a status against itself until this was added.
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
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
    // Two frames rather than pumpAndSettle: the page hosts a RefreshIndicator,
    // which never settles. Mirrors the golden test's harness.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// The badge's background. Read off the nearest `DecoratedBox` above the
  /// label rather than off a `Container`: `Container` is a convenience widget
  /// that builds one, so it is the `DecoratedBox` that carries the decoration
  /// in the element tree.
  Color badgeColour(WidgetTester tester, String label) {
    final box = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
          .first,
    );
    return (box.decoration as BoxDecoration).color!;
  }

  // The label a merchant actually reads, per status. `_statusLabel`'s old
  // `default:` returned the raw status string, which is how PAST_DUE reached a
  // merchant's screen in Latin capitals.
  const labels = <String, String>{
    'ACTIVE': 'Активна',
    'TRIAL': 'Пробный период',
    'PAST_DUE': 'Просрочена',
    'CANCELLED': 'Отменена',
    'EXPIRED': 'Истекла',
  };

  for (final entry in labels.entries) {
    testWidgets('should label a ${entry.key} subscription "${entry.value}"', (
      tester,
    ) async {
      await pumpWithStatus(tester, entry.key);

      expect(find.text(entry.value), findsOneWidget);
      // No other status's label may appear: this is what catches a transposed
      // pair, which a per-status assertion on its own would not.
      for (final other in labels.values.where((v) => v != entry.value)) {
        expect(find.text(other), findsNothing, reason: 'also showed "$other"');
      }
      // And never the raw enum name.
      expect(find.text(entry.key), findsNothing);
    });
  }

  testWidgets(
    'should name an unrecognised status rather than printing it raw',
    (tester) async {
      await pumpWithStatus(tester, 'SOMETHING_NEW');

      expect(find.text('Статус неизвестен'), findsOneWidget);
      expect(find.text('SOMETHING_NEW'), findsNothing);
    },
  );

  testWidgets(
    'should give a lapsed-and-billable subscription a different badge colour '
    'from a cancelled one',
    (tester) async {
      // PAST_DUE is a problem the merchant has to act on; CANCELLED is a
      // settled end state they chose. The spec gives the first EXPIRED's error
      // colour and the second the muted one. Compared rather than pinned to an
      // exact ARGB, so a theme change does not break the test while a
      // transposition still does.
      await pumpWithStatus(tester, 'PAST_DUE');
      final pastDue = badgeColour(tester, 'Просрочена');

      await pumpWithStatus(tester, 'CANCELLED');
      final cancelled = badgeColour(tester, 'Отменена');

      await pumpWithStatus(tester, 'EXPIRED');
      final expired = badgeColour(tester, 'Истекла');

      expect(pastDue, isNot(cancelled));
      expect(pastDue, expired);
    },
  );
}
