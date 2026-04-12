import { SetMetadata } from '@nestjs/common';
import { REQUIRED_FEATURE_KEY } from '../guards/subscription.guard';

export const RequiresFeature = (feature: string) =>
  SetMetadata(REQUIRED_FEATURE_KEY, feature);
