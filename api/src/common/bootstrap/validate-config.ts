import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

const logger = new Logger('ConfigValidator');

const PLACEHOLDER_SECRETS = new Set<string>([
  '__REPLACE_WITH_RANDOM_64_BYTE_HEX__',
  'access-secret-dev',
  'refresh-secret-dev',
  'dokonpro-access-secret-change-in-production-32chars',
  'dokonpro-refresh-secret-change-in-production-32chars',
]);

/**
 * Validate required runtime config at boot. Fails fast on misconfigured
 * secrets so that a mistyped deploy never silently signs tokens with a
 * predictable dev placeholder (BE-P1-007).
 *
 * Enforced rules:
 *  - JWT_ACCESS_SECRET and JWT_REFRESH_SECRET are both set and non-empty
 *  - Neither is one of the known placeholder strings
 *  - They are not equal to each other (otherwise refresh tokens could be
 *    presented as access tokens and vice versa)
 *  - Each is at least 32 characters long
 *  - In production: CORS_ORIGIN must be explicitly set (BE-P1-005)
 */
export function validateBootConfig(configService: ConfigService): void {
  const access = configService.get<string>('JWT_ACCESS_SECRET');
  const refresh = configService.get<string>('JWT_REFRESH_SECRET');

  const checkSecret = (name: string, value: string | undefined) => {
    if (!value || value.trim() === '') {
      throw new Error(`${name} is required but unset. See api/.env.example.`);
    }
    if (PLACEHOLDER_SECRETS.has(value)) {
      throw new Error(
        `${name} is still set to a known placeholder. Generate a fresh ` +
          `64-byte hex secret: \`bash api/scripts/setup-env.sh\` or ` +
          `\`node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"\``,
      );
    }
    if (value.length < 32) {
      throw new Error(
        `${name} must be at least 32 characters (got ${value.length}).`,
      );
    }
  };

  checkSecret('JWT_ACCESS_SECRET', access);
  checkSecret('JWT_REFRESH_SECRET', refresh);

  if (access === refresh) {
    throw new Error(
      'JWT_ACCESS_SECRET must not equal JWT_REFRESH_SECRET — otherwise ' +
        'refresh tokens could be replayed as access tokens.',
    );
  }

  const nodeEnv = configService.get<string>('NODE_ENV', 'development');
  const corsOrigin = configService.get<string>('CORS_ORIGIN');
  if (nodeEnv === 'production') {
    if (!corsOrigin || corsOrigin.trim() === '' || corsOrigin.trim() === '*') {
      throw new Error(
        "CORS_ORIGIN must be explicitly set to the app's origin in " +
          'production. A wildcard (or empty) value with credentials enabled ' +
          'is a CSRF vector.',
      );
    }
  }

  logger.log('Boot config validation OK');
}
