import {
  registerDecorator,
  ValidationArguments,
  ValidationOptions,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';

// Reject anything that looks like HTML/script content or the kind of
// punctuation sequences used to smuggle SQL/JS payloads. Intentionally
// permissive enough that Cyrillic, Latin, digits, spaces, and common
// business punctuation still pass — Tajik/Uzbek retail names routinely
// use apostrophes, ampersands, dashes, and dots.
const FORBIDDEN_PATTERNS: readonly RegExp[] = [
  /<[^>]*>/, // any HTML-ish tag
  /<\/?\w+/, // closing or opening tag fragment
  /<script/i,
  /javascript:/i,
  /on\w+\s*=/i, // onload=, onclick=, ...
  /&#x?[0-9a-f]+;?/i, // numeric / hex HTML entities
  /\b(drop|delete|truncate|insert|update|select)\s+(table|from|into|set)\b/i,
  /--/, // SQL comment
  /;\s*drop/i,
  /;\s*shutdown/i,
];

@ValidatorConstraint({ name: 'isSafeText', async: false })
export class IsSafeTextConstraint implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    if (value == null) return true; // optional fields handled by IsOptional
    if (typeof value !== 'string') return false;
    if (value.length === 0) return true; // empty string lets IsNotEmpty decide
    for (const pat of FORBIDDEN_PATTERNS) {
      if (pat.test(value)) return false;
    }
    return true;
  }

  defaultMessage(args: ValidationArguments): string {
    return `${args.property} contains forbidden characters (HTML tags, scripts, or SQL keywords)`;
  }
}

/**
 * Reject field values that look like HTML, JS, or obvious SQL payloads.
 * Attach to name/display-text fields that are rendered verbatim in the UI
 * or embedded in receipts / PDFs (FD-P1-005).
 */
export function IsSafeText(validationOptions?: ValidationOptions) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      target: object.constructor,
      propertyName,
      options: validationOptions,
      validator: IsSafeTextConstraint,
    });
  };
}
