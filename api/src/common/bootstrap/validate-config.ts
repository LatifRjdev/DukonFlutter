import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

const logger = new Logger('ConfigValidator');

const PLACEHOLDER_SECRETS = new Set<string>([
  '__REPLACE_WITH_RANDOM_64_BYTE_HEX__',
  'access-secret-dev',
  'refresh-secret-dev',
  'duckonpro-access-secret-change-in-production-32chars',
  'duckonpro-refresh-secret-change-in-production-32chars',
]);

function checkSecret(name: string, value: string | undefined): void {
  if (!value || value.trim() === '') {
    throw new Error(
      `${name} is required but unset. See api/.env.example or run ` +
        `\`bash api/scripts/setup-env.sh\`.`,
    );
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
}

/**
 * Validate required runtime config BEFORE Nest starts bootstrapping
 * modules. Called from main.ts before `NestFactory.create(AppModule)`
 * so that JwtStrategy / JwtAccessStrategy never get instantiated with
 * a missing secret — otherwise passport-jwt's own constructor throws
 * a less-informative error first (BE-P0-002, BE-P1-007).
 *
 * Reads directly from process.env because `ConfigService` is not yet
 * available at this point. Nest's @nestjs/config loads .env files via
 * dotenv when ConfigModule boots; we need to replicate that here or
 * we miss values that live only in .env.
 */
export function validateEnvBeforeBoot(): void {
  // Lazy-load dotenv so unit tests that don't need .env don't fail.
  // dotenv is pulled in transitively by @nestjs/config so it is always
  // present at runtime.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const dotenv = require('dotenv') as {
    config: (opts: { path: string }) => void;
  };
  // .env lives in the api/ dir relative to dist/main
  dotenv.config({ path: `${process.cwd()}/.env` });

  const access = process.env.JWT_ACCESS_SECRET;
  const refresh = process.env.JWT_REFRESH_SECRET;

  checkSecret('JWT_ACCESS_SECRET', access);
  checkSecret('JWT_REFRESH_SECRET', refresh);

  if (access === refresh) {
    throw new Error(
      'JWT_ACCESS_SECRET must not equal JWT_REFRESH_SECRET — otherwise ' +
        'refresh tokens could be replayed as access tokens.',
    );
  }

  const nodeEnv = process.env.NODE_ENV ?? 'development';
  const corsOrigin = process.env.CORS_ORIGIN;
  if (nodeEnv === 'production') {
    if (!corsOrigin || corsOrigin.trim() === '' || corsOrigin.trim() === '*') {
      throw new Error(
        "CORS_ORIGIN must be explicitly set to the app's origin in " +
          'production. A wildcard (or empty) value with credentials enabled ' +
          'is a CSRF vector.',
      );
    }
  }

  logger.log('Pre-boot config validation OK');
}

/**
 * Post-bootstrap re-validation using the Nest ConfigService. Kept as a
 * belt-and-braces check in case someone calls the bootstrap path
 * differently (e.g. in E2E tests) and skips validateEnvBeforeBoot.
 * Accepts the same rules as validateEnvBeforeBoot.
 */
export function validateBootConfig(configService: ConfigService): void {
  const access = configService.get<string>('JWT_ACCESS_SECRET');
  const refresh = configService.get<string>('JWT_REFRESH_SECRET');

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
          'production.',
      );
    }
  }

  logger.log('Boot config validation OK');
}
