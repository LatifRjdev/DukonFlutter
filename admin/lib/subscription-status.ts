/**
 * The single source for how a subscription status is spelled, labelled and
 * coloured in the admin.
 *
 * Three pages used to each keep their own copy of these maps. Two of them
 * spelled the cancelled state `CANCELED` with one L while Prisma's
 * `SubscriptionStatus` spells it `CANCELLED`. A cancelled subscription
 * therefore fell through both lookups and rendered the raw English enum with
 * no badge colour, and because the subscriptions list filters client-side on
 * `s.status === statusFilter`, picking "Отменены" matched nothing and showed
 * an empty list. The export link carried the misspelling to the API, which
 * rejected it with a 400.
 *
 * `users/[id]/page.tsx` still renders status with its own ternary and has no
 * cancelled branch at all; it uses a different badge style, so it is left for
 * a follow-up rather than forced through these helpers.
 *
 * Keep `SUBSCRIPTION_STATUSES` in Prisma's spelling; the type below makes a
 * missing entry a compile error rather than a blank badge.
 */
export const SUBSCRIPTION_STATUSES = [
  'TRIAL',
  'ACTIVE',
  'PAST_DUE',
  'CANCELLED',
  'EXPIRED',
] as const;

export type SubscriptionStatus = (typeof SUBSCRIPTION_STATUSES)[number];

export const SUB_STATUS_LABELS: Record<SubscriptionStatus, string> = {
  TRIAL: 'Пробная',
  ACTIVE: 'Активна',
  PAST_DUE: 'Просрочена',
  CANCELLED: 'Отменена',
  EXPIRED: 'Истекла',
};

export const SUB_STATUS_COLORS: Record<SubscriptionStatus, string> = {
  TRIAL: 'bg-blue-100 text-blue-700',
  ACTIVE: 'bg-green-100 text-green-700',
  PAST_DUE: 'bg-yellow-100 text-yellow-700',
  CANCELLED: 'bg-gray-100 text-gray-600',
  EXPIRED: 'bg-red-100 text-red-700',
};

/// Outline palette, for the places that use `variant="outline"` badges. Same
/// vocabulary, different surface — kept here rather than as a fourth local map
/// so it cannot drift from the labels it sits next to.
export const SUB_STATUS_OUTLINE: Record<SubscriptionStatus, string> = {
  TRIAL: 'text-blue-700 border-blue-300',
  ACTIVE: 'text-green-700 border-green-300',
  PAST_DUE: 'text-yellow-700 border-yellow-300',
  CANCELLED: 'text-gray-600 border-gray-300',
  EXPIRED: 'text-red-700 border-red-300',
};

/// As with [subStatusColor], an unknown status must not look like a cancelled
/// one.
export const subStatusOutline = (status: string): string =>
  SUB_STATUS_OUTLINE[status as SubscriptionStatus] ??
  'text-purple-700 border-purple-300';

/** Falls back to the raw value so an enum added server-side still renders. */
export const subStatusLabel = (status: string): string =>
  SUB_STATUS_LABELS[status as SubscriptionStatus] ?? status;

/// Deliberately NOT the grey CANCELLED uses: a status added server-side must
/// not be visually indistinguishable from a cancelled subscription.
export const subStatusColor = (status: string): string =>
  SUB_STATUS_COLORS[status as SubscriptionStatus] ??
  'bg-purple-100 text-purple-700';

export const SUBSCRIPTION_PLANS = ['START', 'BUSINESS', 'PREMIUM'] as const;

export type SubscriptionPlan = (typeof SUBSCRIPTION_PLANS)[number];
