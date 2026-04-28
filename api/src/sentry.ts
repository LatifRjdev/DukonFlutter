import * as Sentry from '@sentry/nestjs';
import { nodeProfilingIntegration } from '@sentry/profiling-node';

export function initSentry(): void {
  const dsn = process.env.SENTRY_DSN;
  const env = process.env.NODE_ENV || 'development';

  if (!dsn) {
    if (env === 'production') {
      throw new Error(
        'SENTRY_DSN env var is required in production. ' +
          'Set it via your deployment secret store.',
      );
    }
    return;
  }

  Sentry.init({
    dsn,
    environment: env,
    integrations: [nodeProfilingIntegration()],
    tracesSampleRate: env === 'production' ? 0.1 : 0,
    profilesSampleRate: env === 'production' ? 0.1 : 0,
    sendDefaultPii: false,
  });
}
