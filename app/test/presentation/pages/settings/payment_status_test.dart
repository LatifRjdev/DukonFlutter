import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dukonpro/presentation/pages/settings/payment_status.dart';

// Guards the exact defect this file was extracted for: the subscription page
// switched on 'CONFIRMED', a value `enum PaymentStatus` in
// api/prisma/schema.prisma has never contained. The admin's approve action
// writes APPROVED, so an approved payment fell through to `default:` and the
// merchant was told indefinitely that it was still pending.
void main() {
  test('should treat APPROVED as a settled, successful payment', () {
    expect(paymentStatusKind('APPROVED'), PaymentStatusKind.approved);
  });

  test('should treat COMPLETED as a settled, successful payment', () {
    expect(paymentStatusKind('COMPLETED'), PaymentStatusKind.approved);
  });

  test('should treat REJECTED as a settled, failed payment', () {
    expect(paymentStatusKind('REJECTED'), PaymentStatusKind.rejected);
  });

  test('should not report a failed payment as rejected by an admin', () {
    // REJECTED means a person refused the receipt and left a reason; FAILED
    // means the payment never went through. One label over both would tell a
    // merchant with a failed card that someone turned them down.
    expect(paymentStatusKind('FAILED'), PaymentStatusKind.failed);
  });

  test('should treat PENDING as awaiting review', () {
    expect(paymentStatusKind('PENDING'), PaymentStatusKind.pending);
  });

  test('should treat a refund as its own outcome', () {
    // Pinned exactly, not as `isNot(rejected)` — that passed for three of the
    // four kinds and left the one kind this change introduced unpinned.
    expect(paymentStatusKind('REFUNDED'), PaymentStatusKind.refunded);
  });

  test('should not report an unknown status as pending', () {
    // The old `default:` swallowed everything, which is precisely how APPROVED
    // came to render as "Ожидает". An unrecognised value has to be visibly
    // its own thing, or the defect returns in a new shape.
    expect(paymentStatusKind('SOMETHING_NEW'), PaymentStatusKind.unknown);
  });

  test('should cover every PaymentStatus the schema actually defines', () {
    // Reads the schema rather than restating it. A hardcoded list is where
    // someone would have to REMEMBER to add a value; this is where the build
    // tells them. Mirrors the admin's subscription-status test, which parses
    // the same file.
    final schema = File('../api/prisma/schema.prisma').readAsStringSync();
    final block =
        RegExp(r'^enum PaymentStatus\s*\{([^}]*)\}', multiLine: true)
            .firstMatch(schema);
    expect(block, isNotNull, reason: 'PaymentStatus not found in schema.prisma');

    final fromSchema = block!
        .group(1)!
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'//.*$'), '').trim())
        .where((l) => l.isNotEmpty);

    for (final status in fromSchema) {
      expect(paymentStatusKind(status), isNot(PaymentStatusKind.unknown),
          reason: '$status has no deliberate mapping');
    }
  });
}
