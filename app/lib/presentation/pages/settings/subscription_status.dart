/// What a subscription's status means, as a value rather than a string.
///
/// Mirrors `enum SubscriptionStatus` in `api/prisma/schema.prisma`. `PAST_DUE`
/// used to appear nowhere in this app: `subscription_state.dart` kept two
/// hand-written lists (`isActive` = ACTIVE|TRIAL, `isExpired` =
/// EXPIRED|CANCELLED) over a five-value enum, so a lapsed merchant was in
/// neither and got a full-colour, healthy-looking plan card; and the page's
/// `_statusLabel` had a `default:` returning the raw status, so the badge
/// printed `PAST_DUE` in Latin capitals.
///
/// The server has no such ambiguity — `api/src/common/guards/feature-flag.helper.ts`
/// documents the gate as ACTIVE/TRIAL allowed, everything else denied, and
/// names PAST_DUE/CANCELLED/EXPIRED together as lapsed. This enum exists so the
/// client states that rule once instead of in three places that agree by
/// coincidence.
///
/// Deliberately free of Flutter imports: the bloc's state objects depend on it.
enum SubscriptionStatusKind {
  active,

  /// Allowed by the server exactly like [active], but kept separate because the
  /// plan card renders a trial countdown where a paid plan renders an expiry
  /// date.
  trial,

  /// Lapsed and billable: the server refuses every gated feature. Treated as a
  /// problem the merchant must act on, not a neutral end state — which is why
  /// it takes the error colour rather than the muted one [cancelled] gets.
  pastDue,

  /// The merchant's own decision.
  cancelled,

  /// Ran out without being renewed.
  expired,

  /// A status the schema has gained and this file has not. Must stay on the
  /// pessimistic side of `isActive`: a status we cannot recognise is one we
  /// cannot promise is working, and a grey card that under-promises beats a
  /// colour card that over-promises.
  unknown,
}

SubscriptionStatusKind subscriptionStatusKind(String status) =>
    switch (status) {
      'ACTIVE' => SubscriptionStatusKind.active,
      'TRIAL' => SubscriptionStatusKind.trial,
      'PAST_DUE' => SubscriptionStatusKind.pastDue,
      'CANCELLED' => SubscriptionStatusKind.cancelled,
      'EXPIRED' => SubscriptionStatusKind.expired,
      _ => SubscriptionStatusKind.unknown,
    };
