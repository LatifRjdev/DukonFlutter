import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { ExecutionContext } from '@nestjs/common';
import { LoyaltyController } from './loyalty.controller';
import { LoyaltyService } from './loyalty.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { SubscriptionGuard } from '../../common/guards/subscription.guard';

// Allow all requests through — we are unit-testing the controller delegation,
// not the guards.
const passThroughGuard = { canActivate: (_ctx: ExecutionContext) => true };

const mockService = {
  getSettings: jest.fn(async () => ({ storeId: 'store-1', isEnabled: true })),
  updateSettings: jest.fn(async () => ({ storeId: 'store-1', isEnabled: false })),
  getCustomerBalance: jest.fn(async () => ({ points: 100, transactions: [] })),
};

describe('LoyaltyController', () => {
  let controller: LoyaltyController;

  beforeEach(async () => {
    jest.clearAllMocks();

    const moduleRef = await Test.createTestingModule({
      controllers: [LoyaltyController],
      providers: [{ provide: LoyaltyService, useValue: mockService }],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue(passThroughGuard)
      .overrideGuard(StoreAccessGuard)
      .useValue(passThroughGuard)
      .overrideGuard(SubscriptionGuard)
      .useValue(passThroughGuard)
      .compile();

    controller = moduleRef.get(LoyaltyController);
  });

  describe('getSettings', () => {
    it('should call loyaltyService.getSettings with storeId and return the result', async () => {
      const result = await controller.getSettings('store-1');

      expect(mockService.getSettings).toHaveBeenCalledWith('store-1');
      expect(result).toEqual({ storeId: 'store-1', isEnabled: true });
    });
  });

  describe('updateSettings', () => {
    it('should call loyaltyService.updateSettings with storeId and dto and return the result', async () => {
      const dto = { isEnabled: false } as any;

      const result = await controller.updateSettings('store-1', dto);

      expect(mockService.updateSettings).toHaveBeenCalledWith('store-1', dto);
      expect(result).toEqual({ storeId: 'store-1', isEnabled: false });
    });
  });

  describe('getCustomerBalance', () => {
    it('should call loyaltyService.getCustomerBalance with storeId and customerId and return balance', async () => {
      const result = await controller.getCustomerBalance('store-1', 'cust-1');

      expect(mockService.getCustomerBalance).toHaveBeenCalledWith('store-1', 'cust-1');
      expect(result).toEqual({ points: 100, transactions: [] });
    });
  });
});
