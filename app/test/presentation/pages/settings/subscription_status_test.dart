import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/presentation/pages/settings/subscription_status.dart';

// Guards the defect this file was extracted for: PAST_DUE appeared nowhere in
// the app. It was in neither of subscription_state's two hand-kept lists, so a
// lapsed merchant got a full-colour plan card, and it fell through the page's
// two `default:` branches, so the badge printed the raw enum name in Latin
// capitals while the server refused every gated feature.
void main() {
  test('should recognise PAST_DUE rather than falling through to unknown', () {
    expect(subscriptionStatusKind('PAST_DUE'), SubscriptionStatusKind.pastDue);
  });

  test('should treat ACTIVE as a working subscription', () {
    expect(subscriptionStatusKind('ACTIVE'), SubscriptionStatusKind.active);
  });

  test('should treat TRIAL as a working subscription', () {
    expect(subscriptionStatusKind('TRIAL'), SubscriptionStatusKind.trial);
  });

  test('should keep TRIAL distinct from ACTIVE', () {
    // Both are allowed by the server, but the card renders them differently —
    // TRIAL carries a countdown and ACTIVE carries an expiry date. Collapsing
    // them into one kind would lose that.
    expect(
      subscriptionStatusKind('TRIAL'),
      isNot(subscriptionStatusKind('ACTIVE')),
    );
  });

  test('should treat CANCELLED as its own end state', () {
    expect(
      subscriptionStatusKind('CANCELLED'),
      SubscriptionStatusKind.cancelled,
    );
  });

  test('should treat EXPIRED as its own end state', () {
    // Pinned exactly rather than as "not active". CANCELLED is a decision the
    // merchant made and EXPIRED is one that happened to them; the page gives
    // them different colours, so one kind over both would be wrong.
    expect(subscriptionStatusKind('EXPIRED'), SubscriptionStatusKind.expired);
  });

  test('should not fold an unrecognised status into a working one', () {
    expect(
      subscriptionStatusKind('SOMETHING_NEW'),
      SubscriptionStatusKind.unknown,
    );
  });

  test('should cover every SubscriptionStatus the schema actually defines', () {
    // Reads the schema rather than restating it. A hardcoded list is where
    // someone would have to REMEMBER to add a value; this is where the build
    // tells them. Mirrors payment_status_test.dart and the admin's
    // subscription-status test, both of which parse the same file.
    final schema = File('../api/prisma/schema.prisma').readAsStringSync();
    final block = RegExp(
      r'^enum SubscriptionStatus\s*\{([^}]*)\}',
      multiLine: true,
    ).firstMatch(schema);
    expect(
      block,
      isNotNull,
      reason: 'SubscriptionStatus not found in schema.prisma',
    );

    final fromSchema = block!
        .group(1)!
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'//.*$'), '').trim())
        .where((l) => l.isNotEmpty);

    for (final status in fromSchema) {
      expect(
        subscriptionStatusKind(status),
        isNot(SubscriptionStatusKind.unknown),
        reason: '$status has no deliberate mapping',
      );
    }
  });
}
