import { SetMetadata } from '@nestjs/common';
import { REQUIRED_PLAN_KEY } from '../guards/subscription.guard';

export const RequiresPlan = (plan: string) =>
  SetMetadata(REQUIRED_PLAN_KEY, plan);
