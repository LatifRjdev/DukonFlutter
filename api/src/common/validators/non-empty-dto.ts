import { BadRequestException } from '@nestjs/common';

/**
 * Reject DTOs whose body is `{}` or contains only undefined properties.
 *
 * Several settings endpoints (receipt-template, zakat-settings) accept
 * fully-optional DTOs — without this guard, an empty body would silently
 * persist a row of nulls / defaults and overwrite the existing value.
 *
 * Closes the carryover P2 from qa/2026-05-06-api-audit.md
 * (also flagged in qa/2026-05-07-deep/SUMMARY.md).
 */
export function assertNonEmptyDto(
  dto: object,
  fieldName: string = 'body',
): void {
  const definedKeys = Object.entries(dto).filter(
    ([, value]) => value !== undefined,
  );
  if (definedKeys.length === 0) {
    throw new BadRequestException(
      `${fieldName} must contain at least one property to update.`,
    );
  }
}
