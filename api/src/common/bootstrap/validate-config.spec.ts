import { ConfigService } from '@nestjs/config';
import { validateBootConfig } from './validate-config';

// Focused on the TELEGRAM_WEBHOOK_SECRET production gate added alongside
// the fix for the P1 finding: TelegramController.handleWebhook accepts
// unauthenticated requests when this env var is unset, so production boot
// must fail closed instead. Pre-existing JWT/CORS checks are exercised
// implicitly (a valid baseline is required for these tests to reach the
// Telegram check at all) but are not the focus of new coverage here.

describe('validateBootConfig — TELEGRAM_WEBHOOK_SECRET production gate', () => {
  const validBase: Record<string, string> = {
    JWT_ACCESS_SECRET: 'a'.repeat(32),
    JWT_REFRESH_SECRET: 'b'.repeat(32),
    CORS_ORIGIN: 'https://app.dukonpro.tj',
  };

  function makeConfigService(overrides: Record<string, string | undefined>) {
    const values = { ...validBase, ...overrides };
    return {
      get: jest.fn((key: string) => values[key]),
    } as unknown as ConfigService;
  }

  it('should throw when NODE_ENV=production and TELEGRAM_WEBHOOK_SECRET is unset', () => {
    const config = makeConfigService({
      NODE_ENV: 'production',
      TELEGRAM_WEBHOOK_SECRET: undefined,
    });

    expect(() => validateBootConfig(config)).toThrow(
      /TELEGRAM_WEBHOOK_SECRET is required in production/,
    );
  });

  it('should throw when NODE_ENV=production and TELEGRAM_WEBHOOK_SECRET is only whitespace', () => {
    const config = makeConfigService({
      NODE_ENV: 'production',
      TELEGRAM_WEBHOOK_SECRET: '   ',
    });

    expect(() => validateBootConfig(config)).toThrow(
      /TELEGRAM_WEBHOOK_SECRET is required in production/,
    );
  });

  it('should throw when NODE_ENV=production and TELEGRAM_WEBHOOK_SECRET is shorter than 16 characters', () => {
    const config = makeConfigService({
      NODE_ENV: 'production',
      TELEGRAM_WEBHOOK_SECRET: 'short-secret',
    });

    expect(() => validateBootConfig(config)).toThrow(
      /must be at least 16 characters/,
    );
  });

  it('should not throw when NODE_ENV=production and TELEGRAM_WEBHOOK_SECRET is a valid length', () => {
    const config = makeConfigService({
      NODE_ENV: 'production',
      TELEGRAM_WEBHOOK_SECRET: 'a-sufficiently-long-random-webhook-secret',
    });

    expect(() => validateBootConfig(config)).not.toThrow();
  });

  it('should not require TELEGRAM_WEBHOOK_SECRET when NODE_ENV is not production', () => {
    const config = makeConfigService({
      NODE_ENV: 'development',
      TELEGRAM_WEBHOOK_SECRET: undefined,
    });

    expect(() => validateBootConfig(config)).not.toThrow();
  });

  it('should still enforce the pre-existing CORS_ORIGIN production check independently', () => {
    const config = makeConfigService({
      NODE_ENV: 'production',
      CORS_ORIGIN: '',
      TELEGRAM_WEBHOOK_SECRET: 'a-sufficiently-long-random-webhook-secret',
    });

    expect(() => validateBootConfig(config)).toThrow(
      /CORS_ORIGIN must be explicitly set/,
    );
  });
});
