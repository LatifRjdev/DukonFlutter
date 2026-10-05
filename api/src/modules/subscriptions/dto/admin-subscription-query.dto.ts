import { IsEnum, IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { SubscriptionPlan, SubscriptionStatus } from '@prisma/client';

export class AdminSubscriptionQueryDto {
  // Validated against the enum, not merely IsString: an unknown value used to
  // sail through here and blow up inside Prisma as a 500. Not reachable from
  // the admin UI — that list fetches without params and filters client-side —
  // so this is hardening for direct and Swagger callers, and it brings this
  // DTO into line with AdminSubscriptionExportQueryDto, which already
  // validated both fields.
  @ApiPropertyOptional({ enum: SubscriptionStatus })
  @IsOptional()
  @IsEnum(SubscriptionStatus)
  status?: SubscriptionStatus;

  @ApiPropertyOptional({ enum: SubscriptionPlan })
  @IsOptional()
  @IsEnum(SubscriptionPlan)
  plan?: SubscriptionPlan;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  search?: string;
}
