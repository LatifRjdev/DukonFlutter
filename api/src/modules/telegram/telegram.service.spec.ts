import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TelegramService } from './telegram.service';
import { PrismaService } from '../../prisma/prisma.service';

// The Telegram bot client is a third-party HTTP boundary (node-telegram-bot-api
// wraps the real Telegram Bot API over HTTPS). We fake the module itself so no
// real network call is ever made, and expose a behavioral fake instance whose
// methods we can configure/assert per test — the constructor mock always
// returns the same instance so tests can reach into it via `botInstance`.
let botInstance: {
  sendMessage: jest.Mock;
  getChat: jest.Mock;
};

jest.mock('node-telegram-bot-api', () => {
  return jest.fn().mockImplementation(() => botInstance);
});

// Behavioral fake for PrismaService. Tracks customers, users, stores and
// sales in Maps and implements the subset of Prisma methods TelegramService
// actually calls, with real lookup/update behavior rather than stubbed
// returns.
function makePrismaFake() {
  type CustomerRow = {
    id: string;
    storeId: string;
    name: string;
    phone: string | null;
    telegramChatId: string | null;
  };
  type UserRow = {
    id: string;
    phone: string | null;
    telegramChatId: string | null;
  };
  type StoreRow = {
    id: string;
    name: string;
    ownerId: string | null;
  };
  type SaleRow = {
    id: string;
    storeId: string;
    receiptNo: string;
    total: number;
    paymentType: string;
    createdAt: Date;
    store: StoreRow;
    customer: CustomerRow | null;
    items: Array<{
      productName: string;
      quantity: number;
      total: number;
    }>;
  };

  const customers = new Map<string, CustomerRow>();
  const users = new Map<string, UserRow>();
  const sales = new Map<string, SaleRow>();

  return {
    _customers: customers,
    _users: users,
    _sales: sales,
    customer: {
      findFirst: jest.fn(async ({ where }: any) => {
        for (const c of customers.values()) {
          if (where.phone && c.phone !== where.phone) continue;
          return { ...c };
        }
        return null;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const c = customers.get(where.id);
        if (!c) throw new Error('not found');
        Object.assign(c, data);
        return { ...c };
      }),
    },
    user: {
      findUnique: jest.fn(async ({ where }: any) => {
        for (const u of users.values()) {
          if (where.phone && u.phone !== where.phone) continue;
          return { ...u };
        }
        return null;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const u = users.get(where.id);
        if (!u) throw new Error('not found');
        Object.assign(u, data);
        return { ...u };
      }),
    },
    sale: {
      findFirst: jest.fn(async ({ where }: any) => {
        for (const s of sales.values()) {
          if (where.id && s.id !== where.id) continue;
          if (where.storeId && s.storeId !== where.storeId) continue;
          return { ...s };
        }
        return null;
      }),
    },
    store: {
      findUnique: jest.fn(async ({ where }: any) => {
        const store = Array.from(sales.values()).find(
          (s) => s.store.id === where.id,
        )?.store;
        return store ? { ...store } : null;
      }),
    },
  };
}

function makeConfigFake(values: Record<string, string | undefined>) {
  return {
    get: jest.fn((key: string) => values[key]),
  } as unknown as ConfigService;
}

describe('TelegramService', () => {
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(() => {
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => {});
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => {});
    jest.spyOn(Logger.prototype, 'debug').mockImplementation(() => {});
    prisma = makePrismaFake();
    botInstance = {
      sendMessage: jest.fn().mockResolvedValue(undefined),
      getChat: jest.fn(),
    };
  });

  const buildService = async (
    configValues: Record<string, string | undefined> = {
      TELEGRAM_BOT_TOKEN: 'test-token',
    },
  ) => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        TelegramService,
        { provide: PrismaService, useValue: prisma },
        { provide: ConfigService, useValue: makeConfigFake(configValues) },
      ],
    }).compile();
    return moduleRef.get(TelegramService);
  };

  describe('constructor / bot initialization', () => {
    it('should disable the bot without throwing when TELEGRAM_BOT_TOKEN is not set', async () => {
      const service = await buildService({ TELEGRAM_BOT_TOKEN: undefined });

      // No bot configured, so all bot-dependent methods should no-op safely.
      await expect(
        service.sendMessage('chat-1', 'hello'),
      ).resolves.toBeUndefined();
      expect(botInstance.sendMessage).not.toHaveBeenCalled();
    });
  });

  describe('handleWebhook', () => {
    it('should be a no-op when the bot is not configured', async () => {
      const service = await buildService({ TELEGRAM_BOT_TOKEN: undefined });

      await service.handleWebhook({ update_id: 1 } as any);

      expect(botInstance.sendMessage).not.toHaveBeenCalled();
    });

    it('should be a no-op when the update has no message', async () => {
      const service = await buildService();

      await service.handleWebhook({ update_id: 1 } as any);

      expect(botInstance.sendMessage).not.toHaveBeenCalled();
    });

    it('should send a welcome prompt with a contact-request keyboard when message text starts with /start', async () => {
      const service = await buildService();

      await service.handleWebhook({
        update_id: 1,
        message: {
          chat: { id: 555 },
          text: '/start',
        },
      } as any);

      expect(botInstance.sendMessage).toHaveBeenCalledTimes(1);
      const [chatId, text, options] = botInstance.sendMessage.mock.calls[0];
      expect(chatId).toBe(555);
      expect(text).toContain('DukonPro');
      expect(options.reply_markup.keyboard[0][0].request_contact).toBe(true);
    });

    it('should link the chatId to a matching customer when a contact is shared', async () => {
      const service = await buildService();
      prisma._customers.set('cust-1', {
        id: 'cust-1',
        storeId: 'store-1',
        name: 'Alisher',
        phone: '+992900111222',
        telegramChatId: null,
      });

      await service.handleWebhook({
        update_id: 1,
        message: {
          chat: { id: 777 },
          contact: { phone_number: '992900111222' },
        },
      } as any);

      expect(prisma._customers.get('cust-1')!.telegramChatId).toBe('777');
      expect(botInstance.sendMessage).toHaveBeenCalledWith(
        777,
        expect.stringContaining('Alisher'),
      );
    });

    it('should link the chatId to a matching store-owner user when a contact is shared', async () => {
      const service = await buildService();
      prisma._users.set('user-1', {
        id: 'user-1',
        phone: '+992900111222',
        telegramChatId: null,
      });

      await service.handleWebhook({
        update_id: 1,
        message: {
          chat: { id: 888 },
          contact: { phone_number: '+992900111222' },
        },
      } as any);

      expect(prisma._users.get('user-1')!.telegramChatId).toBe('888');
      expect(botInstance.sendMessage).toHaveBeenCalledWith(
        888,
        expect.stringContaining('владельца'),
      );
    });

    it('should link both customer and user when the same phone matches both records', async () => {
      const service = await buildService();
      prisma._customers.set('cust-1', {
        id: 'cust-1',
        storeId: 'store-1',
        name: 'Alisher',
        phone: '+992900111222',
        telegramChatId: null,
      });
      prisma._users.set('user-1', {
        id: 'user-1',
        phone: '+992900111222',
        telegramChatId: null,
      });

      await service.handleWebhook({
        update_id: 1,
        message: {
          chat: { id: 999 },
          contact: { phone_number: '+992900111222' },
        },
      } as any);

      expect(prisma._customers.get('cust-1')!.telegramChatId).toBe('999');
      expect(prisma._users.get('user-1')!.telegramChatId).toBe('999');
      expect(botInstance.sendMessage).toHaveBeenCalledTimes(2);
    });

    it('should notify the user that the number was not found when no customer or user matches the shared phone', async () => {
      const service = await buildService();

      await service.handleWebhook({
        update_id: 1,
        message: {
          chat: { id: 111 },
          contact: { phone_number: '+992900000000' },
        },
      } as any);

      expect(botInstance.sendMessage).toHaveBeenCalledWith(
        111,
        expect.stringContaining('не найден'),
      );
    });

    it('should be a no-op when message has neither /start text nor a contact', async () => {
      const service = await buildService();

      await service.handleWebhook({
        update_id: 1,
        message: {
          chat: { id: 222 },
          text: 'just chatting',
        },
      } as any);

      expect(botInstance.sendMessage).not.toHaveBeenCalled();
    });
  });

  describe('sendReceipt', () => {
    const seedSale = (overrides: Partial<any> = {}) => {
      const row = {
        id: 'sale-1',
        storeId: 'store-1',
        receiptNo: 'R-1',
        total: 150,
        paymentType: 'CASH',
        createdAt: new Date('2026-01-01T10:00:00Z'),
        store: { id: 'store-1', name: 'Dukon Store', ownerId: 'user-1' },
        customer: {
          id: 'cust-1',
          storeId: 'store-1',
          name: 'Alisher',
          phone: '+992900111222',
          telegramChatId: 'tg-chat-1',
        },
        items: [{ productName: 'Bread', quantity: 2, total: 20 }],
        ...overrides,
      };
      prisma._sales.set(row.id, row as any);
      return row;
    };

    it('should throw NotFoundException when the sale does not belong to the store', async () => {
      const service = await buildService();
      seedSale({ storeId: 'store-1' });

      await expect(
        service.sendReceipt('sale-1', 'store-OTHER'),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(botInstance.sendMessage).not.toHaveBeenCalled();
    });

    it('should send a formatted receipt to the customer chatId when customer has telegramChatId set', async () => {
      const service = await buildService();
      seedSale();

      await service.sendReceipt('sale-1', 'store-1');

      expect(botInstance.sendMessage).toHaveBeenCalledTimes(1);
      const [chatId, text] = botInstance.sendMessage.mock.calls[0];
      expect(chatId).toBe('tg-chat-1');
      expect(text).toContain('R-1');
      expect(text).toContain('Dukon Store');
      expect(text).toContain('Bread');
    });

    it('should skip sending without throwing when the customer has no telegramChatId', async () => {
      const service = await buildService();
      seedSale({
        customer: {
          id: 'cust-1',
          storeId: 'store-1',
          name: 'Alisher',
          phone: '+992900111222',
          telegramChatId: null,
        },
      });

      await expect(
        service.sendReceipt('sale-1', 'store-1'),
      ).resolves.toBeUndefined();
      expect(botInstance.sendMessage).not.toHaveBeenCalled();
    });

    it('should skip sending without throwing when the sale has no customer', async () => {
      const service = await buildService();
      seedSale({ customer: null });

      await expect(
        service.sendReceipt('sale-1', 'store-1'),
      ).resolves.toBeUndefined();
      expect(botInstance.sendMessage).not.toHaveBeenCalled();
    });

    it('should be a no-op when the bot is not configured, even if the sale exists', async () => {
      const service = await buildService({ TELEGRAM_BOT_TOKEN: undefined });
      seedSale();

      await service.sendReceipt('sale-1', 'store-1');

      expect(botInstance.sendMessage).not.toHaveBeenCalled();
    });

    it('should swallow the error and not throw when the Telegram send call fails', async () => {
      const service = await buildService();
      seedSale();
      botInstance.sendMessage.mockRejectedValueOnce(
        new Error('network failure'),
      );

      await expect(
        service.sendReceipt('sale-1', 'store-1'),
      ).resolves.toBeUndefined();
    });
  });

  describe('sendMessage', () => {
    it('should forward chatId and text to the bot client when the bot is configured', async () => {
      const service = await buildService();

      await service.sendMessage('chat-42', 'hello there');

      expect(botInstance.sendMessage).toHaveBeenCalledWith(
        'chat-42',
        'hello there',
      );
    });

    it('should not throw when the underlying bot client rejects', async () => {
      const service = await buildService();
      botInstance.sendMessage.mockRejectedValueOnce(new Error('boom'));

      await expect(
        service.sendMessage('chat-42', 'hello there'),
      ).resolves.toBeUndefined();
    });

    it('should be a no-op when the bot is not configured', async () => {
      const service = await buildService({ TELEGRAM_BOT_TOKEN: undefined });

      await expect(
        service.sendMessage('chat-42', 'hello there'),
      ).resolves.toBeUndefined();
      expect(botInstance.sendMessage).not.toHaveBeenCalled();
    });
  });

  describe('resolveUsername', () => {
    it('should return the chatId as a string when the username resolves to a chat', async () => {
      const service = await buildService();
      botInstance.getChat.mockResolvedValue({ id: 123456789 });

      const result = await service.resolveUsername('alisher');

      expect(botInstance.getChat).toHaveBeenCalledWith('@alisher');
      expect(result).toBe('123456789');
    });

    it('should not double-prefix the @ when the username already includes it', async () => {
      const service = await buildService();
      botInstance.getChat.mockResolvedValue({ id: 42 });

      await service.resolveUsername('@alisher');

      expect(botInstance.getChat).toHaveBeenCalledWith('@alisher');
    });

    it('should return null when the bot client throws (unknown/private username)', async () => {
      const service = await buildService();
      botInstance.getChat.mockRejectedValue(new Error('chat not found'));

      const result = await service.resolveUsername('nobody');

      expect(result).toBeNull();
    });

    it('should return null when the bot is not configured', async () => {
      const service = await buildService({ TELEGRAM_BOT_TOKEN: undefined });

      const result = await service.resolveUsername('alisher');

      expect(result).toBeNull();
      expect(botInstance.getChat).not.toHaveBeenCalled();
    });
  });

  describe('getStoreChatId', () => {
    it("should return the owner's telegramChatId when the store and owner are linked", async () => {
      const service = await buildService();
      const findUniqueMock = jest.fn().mockResolvedValue({
        id: 'store-1',
        owner: { telegramChatId: 'owner-chat-1' },
      });
      (prisma as any).store.findUnique = findUniqueMock;

      const result = await service.getStoreChatId('store-1');

      expect(findUniqueMock).toHaveBeenCalledWith({
        where: { id: 'store-1' },
        include: { owner: { select: { telegramChatId: true } } },
      });
      expect(result).toBe('owner-chat-1');
    });

    it('should return null when the store has no owner chatId linked', async () => {
      const service = await buildService();
      (prisma as any).store.findUnique = jest.fn().mockResolvedValue({
        id: 'store-1',
        owner: { telegramChatId: null },
      });

      const result = await service.getStoreChatId('store-1');

      expect(result).toBeNull();
    });

    it('should return null when the store does not exist', async () => {
      const service = await buildService();
      (prisma as any).store.findUnique = jest.fn().mockResolvedValue(null);

      const result = await service.getStoreChatId('store-missing');

      expect(result).toBeNull();
    });
  });
});
