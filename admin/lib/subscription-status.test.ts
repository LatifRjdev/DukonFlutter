import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  SUBSCRIPTION_STATUSES,
  SUB_STATUS_COLORS,
  SUB_STATUS_LABELS,
  SUB_STATUS_OUTLINE,
  subStatusColor,
  subStatusLabel,
  subStatusOutline,
} from './subscription-status';

describe('subscription status vocabulary', () => {
  // The defect this guards: two pages keyed their maps with CANCELED (one L)
  // while Prisma spells it CANCELLED, so a cancelled subscription rendered the
  // raw English enum and the filter sent a value the API threw 500 on.
  it('should match the SubscriptionStatus enum in the Prisma schema', () => {
    const schema = readFileSync(
      join(__dirname, '../../api/prisma/schema.prisma'),
      'utf8',
    );
    // Anchored to start-of-line so a commented-out enum earlier in the file
    // cannot match first; each member is stripped of a trailing // note and of
    // any @attribute before comparison.
    const block = /^enum SubscriptionStatus\s*\{([^}]*)\}/m.exec(schema);
    expect(block, 'SubscriptionStatus not found in schema.prisma').not.toBeNull();

    const fromSchema = block![1]
      .split('\n')
      .map((l) => l.replace(/\/\/.*$/, '').replace(/@.*$/, '').trim())
      .filter((l) => l.length > 0);

    // Compared in order, which is what the module's comment promises.
    expect([...SUBSCRIPTION_STATUSES]).toEqual(fromSchema);
  });

  it('should label and colour every status, in both palettes', () => {
    for (const status of SUBSCRIPTION_STATUSES) {
      expect(SUB_STATUS_LABELS[status], `label for ${status}`).toBeTruthy();
      expect(SUB_STATUS_COLORS[status], `colour for ${status}`).toBeTruthy();
      expect(SUB_STATUS_OUTLINE[status], `outline for ${status}`).toBeTruthy();
    }
  });

  it('should give two different statuses two different styles', () => {
    // The defect on users/[id] was a catch-all colour, not a missing label:
    // PAST_DUE, CANCELLED and EXPIRED all rendered yellow.
    const solid = SUBSCRIPTION_STATUSES.map((s) => SUB_STATUS_COLORS[s]);
    const outline = SUBSCRIPTION_STATUSES.map((s) => SUB_STATUS_OUTLINE[s]);
    expect(new Set(solid).size).toBe(solid.length);
    expect(new Set(outline).size).toBe(outline.length);
  });

  it('should render a Russian label for a cancelled subscription', () => {
    expect(subStatusLabel('CANCELLED')).toBe('Отменена');
    expect(subStatusColor('CANCELLED')).not.toBe('');
  });

  it('should fall back to the raw value for a status added server-side', () => {
    expect(subStatusLabel('SOMETHING_NEW')).toBe('SOMETHING_NEW');
    expect(subStatusColor('SOMETHING_NEW')).toBeTruthy();
    expect(subStatusOutline('SOMETHING_NEW')).toBeTruthy();
  });

  it('should not make an unknown status look cancelled, in either palette', () => {
    expect(subStatusColor('SOMETHING_NEW')).not.toBe(SUB_STATUS_COLORS.CANCELLED);
    expect(subStatusOutline('SOMETHING_NEW')).not.toBe(SUB_STATUS_OUTLINE.CANCELLED);
  });
});
