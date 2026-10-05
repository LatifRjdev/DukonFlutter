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

  test('should treat FAILED as a settled, failed payment', () {
    expect(paymentStatusKind('FAILED'), PaymentStatusKind.rejected);
  });

  test('should treat PENDING as awaiting review', () {
    expect(paymentStatusKind('PENDING'), PaymentStatusKind.pending);
  });

  test('should not report a refund as a failed payment', () {
    // A refund is a payment that succeeded and was later returned. Folding it
    // into `rejected` would tell a merchant their payment failed.
    expect(paymentStatusKind('REFUNDED'), isNot(PaymentStatusKind.rejected));
  });

  test('should not report an unknown status as pending', () {
    // The old `default:` swallowed everything, which is precisely how APPROVED
    // came to render as "Ожидает". An unrecognised value has to be visibly
    // its own thing, or the defect returns in a new shape.
    expect(paymentStatusKind('SOMETHING_NEW'), PaymentStatusKind.unknown);
  });

  test('should cover every PaymentStatus the schema defines', () {
    // Mirrors enum PaymentStatus in api/prisma/schema.prisma. If a value is
    // added there, this list is where the omission surfaces.
    const fromSchema = [
      'PENDING',
      'APPROVED',
      'REJECTED',
      'COMPLETED',
      'FAILED',
      'REFUNDED',
    ];

    for (final status in fromSchema) {
      expect(paymentStatusKind(status), isNot(PaymentStatusKind.unknown),
          reason: '$status has no deliberate mapping');
    }
  });
}
