import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TelegramController } from './telegram.controller';
import { TelegramService } from './telegram.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';

// Allow all requests through — we are unit-testing controller delegation and
// webhook-secret validation, not the auth/store/subscription guards.
const passThroughGuard = { canActivate: (_ctx: ExecutionContext) => true };

function makeConfigFake(values: Record<string, string | undefined>) {
  return {
    get: jest.fn((key: string) => values[key]),
  } as unknown as ConfigService;
}

describe('TelegramController', () => {
  let telegramService: { handleWebhook: jest.Mock; sendReceipt: jest.Mock };

  beforeEach(() => {
    telegramService = {
      handleWebhook: jest.fn().mockResolvedValue(undefined),
      sendReceipt: jest.fn().mockResolvedValue(undefined),
    };
  });

  const buildController = async (
    configValues: Record<string, string | undefined> = {},
  ) => {
    const moduleRef = await Test.createTestingModule({
      controllers: [TelegramController],
      providers: [
        { provide: TelegramService, useValue: telegramService },
        { provide: ConfigService, useValue: makeConfigFake(configValues) },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue(passThroughGuard)
      .overrideGuard(StoreAccessGuard)
      .useValue(passThroughGuard)
      .overrideGuard(SubscriptionGuard)
      .useValue(passThroughGuard)
      .compile();
    return moduleRef.get(TelegramController);
  };

  describe('handleWebhook', () => {
    it('should forward the update to TelegramService when no secret is configured (dev mode)', async () => {
      const controller = await buildController({
        TELEGRAM_WEBHOOK_SECRET: undefined,
      });
      const update = { update_id: 1 };

      await controller.handleWebhook(update, undefined);

      expect(telegramService.handleWebhook).toHaveBeenCalledWith(update);
    });

    it('should forward the update when the secret header matches the configured secret', async () => {
      const controller = await buildController({
        TELEGRAM_WEBHOOK_SECRET: 'super-secret',
      });
      const update = { update_id: 1 };

      await controller.handleWebhook(update, 'super-secret');

      expect(telegramService.handleWebhook).toHaveBeenCalledWith(update);
    });

    it('should throw ForbiddenException and not call the service when the secret header is missing', async () => {
      const controller = await buildController({
        TELEGRAM_WEBHOOK_SECRET: 'super-secret',
      });

      expect(() =>
        controller.handleWebhook({ update_id: 1 }, undefined),
      ).toThrow(ForbiddenException);
      expect(telegramService.handleWebhook).not.toHaveBeenCalled();
    });

    it('should throw ForbiddenException and not call the service when the secret header does not match', async () => {
      const controller = await buildController({
        TELEGRAM_WEBHOOK_SECRET: 'super-secret',
      });

      expect(() =>
        controller.handleWebhook({ update_id: 1 }, 'wrong-secret'),
      ).toThrow(ForbiddenException);
      expect(telegramService.handleWebhook).not.toHaveBeenCalled();
    });
  });

  describe('sendReceipt', () => {
    it('should delegate to TelegramService with the sale id and storeId param', async () => {
      const controller = await buildController();

      await controller.sendReceipt('store-1', { saleId: 'sale-1' } as any);

      expect(telegramService.sendReceipt).toHaveBeenCalledWith(
        'sale-1',
        'store-1',
      );
    });
  });
});
