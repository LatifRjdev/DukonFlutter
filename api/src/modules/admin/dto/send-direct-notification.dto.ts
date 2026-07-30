import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsString,
  MaxLength,
  Validate,
  ValidateIf,
  ValidationArguments,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';

// Cross-field check: exactly one of userId/storeId must be set — not both,
// not neither. Per-field @ValidateIf below only covers "at least one", since
// class-validator skips *every* decorator on a property (not just the one
// after @ValidateIf) when that property's own condition is false — so a
// same-property constraint can never see the "both set" case. This
// constraint is attached to `title` instead, which has no ValidateIf/
// IsOptional gating of its own, so it always runs and can see both fields.
@ValidatorConstraint({ name: 'exactlyOneOfUserIdOrStoreId', async: false })
class ExactlyOneTargetConstraint implements ValidatorConstraintInterface {
  validate(_value: unknown, args: ValidationArguments): boolean {
    const obj = args.object as SendDirectNotificationDto;
    return Boolean(obj.userId) !== Boolean(obj.storeId);
  }

  defaultMessage(): string {
    return 'Exactly one of userId or storeId must be provided, not both';
  }
}

export class SendDirectNotificationDto {
  @ApiPropertyOptional({
    description:
      'Target a specific user account. Exactly one of userId/storeId must be set.',
  })
  @ValidateIf((o) => !o.storeId)
  @IsNotEmpty()
  @IsString()
  userId?: string;

  @ApiPropertyOptional({
    description:
      'Target every owner+staff of a store. Exactly one of userId/storeId must be set.',
  })
  @ValidateIf((o) => !o.userId)
  @IsNotEmpty()
  @IsString()
  storeId?: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @MaxLength(200)
  @Validate(ExactlyOneTargetConstraint)
  title: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @MaxLength(1000)
  body: string;
}
