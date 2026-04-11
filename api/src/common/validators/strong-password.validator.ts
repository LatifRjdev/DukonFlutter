import {
  registerDecorator,
  ValidationArguments,
  ValidationOptions,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';

// Short list of passwords that routinely top leaked-credential datasets.
// Kept small on purpose — this is the last line of defence, not a full
// zxcvbn check. For a more thorough rule use a password-strength library.
const COMMON_PASSWORDS = new Set<string>([
  '000000',
  '00000000',
  '12345678',
  '123456789',
  '1234567890',
  'password',
  'password1',
  'qwerty',
  'qwerty123',
  'qwertyuiop',
  'abc12345',
  'letmein',
  'welcome',
  'welcome1',
  'admin123',
  'iloveyou',
  'dokonpro',
  'tajikistan',
  'dushanbe',
]);

@ValidatorConstraint({ name: 'isStrongPassword', async: false })
export class IsStrongPasswordConstraint
  implements ValidatorConstraintInterface
{
  validate(value: unknown, args: ValidationArguments): boolean {
    if (typeof value !== 'string') return false;
    if (value.length < 8) return false;

    // Reject if password matches any other field named in `args.constraints`.
    // Used to block "password === phone" when RegisterDto invokes it with
    // ['phone'] as a sibling-field list.
    const siblingFields = (args.constraints as string[] | undefined) ?? [];
    const object = args.object as Record<string, unknown>;
    for (const field of siblingFields) {
      const sibling = object[field];
      if (typeof sibling === 'string' && sibling.trim() === value.trim()) {
        return false;
      }
    }

    // Reject if lowercase form is in the common-password set.
    if (COMMON_PASSWORDS.has(value.toLowerCase())) return false;

    return true;
  }

  defaultMessage(args: ValidationArguments): string {
    const v = args.value;
    if (typeof v !== 'string' || v.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    const siblingFields = (args.constraints as string[] | undefined) ?? [];
    const object = args.object as Record<string, unknown>;
    for (const field of siblingFields) {
      const sibling = object[field];
      if (typeof sibling === 'string' && sibling.trim() === v.trim()) {
        return `Password must not match ${field}`;
      }
    }
    return 'Password is too common — pick something less predictable';
  }
}

/**
 * Decorator for password fields in DTOs. Requires 8+ characters, rejects a
 * small list of well-known leaked passwords, and (optionally) rejects the
 * password if it matches another field on the same DTO — typically the
 * phone number or email, which are both guessable.
 *
 * @example
 *   \@IsStrongPassword(['phone'])
 *   password: string;
 */
export function IsStrongPassword(
  siblingFieldsToReject: string[] = [],
  validationOptions?: ValidationOptions,
) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      target: object.constructor,
      propertyName,
      options: validationOptions,
      constraints: siblingFieldsToReject,
      validator: IsStrongPasswordConstraint,
    });
  };
}
