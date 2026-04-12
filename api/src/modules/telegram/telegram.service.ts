import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import TelegramBot from 'node-telegram-bot-api';

@Injectable()
export class TelegramService {
  private readonly logger = new Logger(TelegramService.name);
  private bot: TelegramBot | null = null;

  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
  ) {
    const token = this.config.get<string>('TELEGRAM_BOT_TOKEN');
    if (!token) {
      this.logger.warn('TELEGRAM_BOT_TOKEN not set — Telegram integration disabled');
      return;
    }

    try {
      // Use polling=false; we receive updates via webhook
      this.bot = new TelegramBot(token, { polling: false });
      this.logger.log('Telegram bot initialized');
    } catch (err) {
      this.logger.error('Failed to initialize Telegram bot', err);
    }
  }

  /** Process a Telegram Update object received at the webhook endpoint. */
  async handleWebhook(update: TelegramBot.Update): Promise<void> {
    if (!this.bot) return;

    const message = update.message;
    if (!message) return;

    const chatId = message.chat.id;

    // Handle /start command
    if (message.text?.startsWith('/start')) {
      await this.bot.sendMessage(
        chatId,
        'Добро пожаловать в DokonPro! 📲\nПожалуйста, отправьте ваш номер телефона для привязки аккаунта.',
        {
          reply_markup: {
            keyboard: [[{ text: '📱 Поделиться номером', request_contact: true }]],
            one_time_keyboard: true,
            resize_keyboard: true,
          },
        },
      );
      return;
    }

    // Handle shared contact (phone number)
    if (message.contact?.phone_number) {
      const rawPhone = message.contact.phone_number.replace(/\D/g, '');
      // Normalize to +992XXXXXXXXX format
      const phone = rawPhone.startsWith('992') ? `+${rawPhone}` : `+${rawPhone}`;

      const customer = await this.prisma.customer.findFirst({
        where: { phone },
      });

      if (!customer) {
        await this.bot.sendMessage(
          chatId,
          'Клиент с таким номером не найден. Обратитесь к продавцу.',
        );
        return;
      }

      await this.prisma.customer.update({
        where: { id: customer.id },
        data: { telegramChatId: String(chatId) },
      });

      await this.bot.sendMessage(
        chatId,
        `✅ Номер привязан! Теперь вы будете получать чеки в Telegram, ${customer.name}.`,
      );
      return;
    }
  }

  /**
   * Format and send a sale receipt to the customer's Telegram chat.
   * No-op if bot is not configured or customer has no chatId.
   */
  async sendReceipt(saleId: string, storeId: string): Promise<void> {
    if (!this.bot) return;

    const sale = await this.prisma.sale.findFirst({
      where: { id: saleId, storeId },
      include: {
        store: true,
        customer: true,
        items: { include: { product: true } },
      },
    });

    if (!sale) throw new NotFoundException('Sale not found');

    const customer = sale.customer;
    if (!customer?.telegramChatId) {
      this.logger.debug(`Customer for sale ${saleId} has no telegramChatId — skipping`);
      return;
    }

    const date = new Date(sale.createdAt);
    const dateStr = date
      .toLocaleString('ru-RU', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
      .replace(',', '');

    const line = '─────────────────';

    const itemLines = sale.items
      .map((item) => {
        const name = item.productName.padEnd(14, ' ').slice(0, 14);
        const qty = `× ${item.quantity}`;
        const total = Number(item.total).toFixed(2);
        return `${name} ${qty.padStart(5)}  ${total}`;
      })
      .join('\n');

    const paymentLabel: Record<string, string> = {
      CASH: 'Наличные',
      CARD: 'Карта',
      DEBT: 'В долг',
      MIXED: 'Смешанный',
      LOYALTY_POINTS: 'Баллы',
    };

    const receipt = [
      `🧾 Чек #${sale.receiptNo} | ${sale.store.name}`,
      `📅 ${dateStr}`,
      line,
      itemLines,
      line,
      `Итого:   ${Number(sale.total).toFixed(2)} сом.`,
      `Оплата: ${paymentLabel[sale.paymentType] ?? sale.paymentType}`,
      line,
      'Спасибо за покупку!',
    ].join('\n');

    try {
      await this.bot.sendMessage(customer.telegramChatId, receipt);
      this.logger.log(`Receipt sent to chatId ${customer.telegramChatId} for sale ${saleId}`);
    } catch (err) {
      this.logger.error(`Failed to send receipt to Telegram for sale ${saleId}`, err);
    }
  }
}
