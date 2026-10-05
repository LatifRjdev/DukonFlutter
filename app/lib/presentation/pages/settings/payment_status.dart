/// How a subscription payment should read to the merchant.
///
/// Mirrors `enum PaymentStatus` in `api/prisma/schema.prisma`. The subscription
/// page used to compare against `'CONFIRMED'`, which that enum has never
/// contained — the admin's approve action writes `APPROVED` — so an approved
/// payment fell into the page's `default:` branch and rendered as "Ожидает".
/// A merchant who had paid, and whose payment an admin had confirmed, was told
/// indefinitely that it was still pending.
///
/// Kept as a separate function rather than inline in the widget so the mapping
/// can be tested against the schema's full value set without pumping a page.
enum PaymentStatusKind {
  pending,
  approved,

  /// An admin refused the receipt. There is a `rejectionReason` column behind
  /// this, and the merchant's next step is to read it and re-upload.
  rejected,

  /// The payment never went through. Distinct from [rejected] because the
  /// merchant's next step is to pay again, not to argue — one label over both
  /// would tell someone with a failed card that a person turned them down.
  failed,
  refunded,

  /// A status the schema has gained and this file has not. Rendered distinctly
  /// on purpose: folding it into [pending] is exactly how the original defect
  /// stayed invisible.
  unknown,
}

PaymentStatusKind paymentStatusKind(String status) => switch (status) {
      'APPROVED' || 'COMPLETED' => PaymentStatusKind.approved,
      'REJECTED' => PaymentStatusKind.rejected,
      'FAILED' => PaymentStatusKind.failed,
      'PENDING' => PaymentStatusKind.pending,
      // Deliberately its own kind, not `rejected`: a refund is a payment that
      // succeeded and was later returned, and saying "отклонён" would be wrong.
      'REFUNDED' => PaymentStatusKind.refunded,
      _ => PaymentStatusKind.unknown,
    };
