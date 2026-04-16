import { Injectable, Logger } from '@nestjs/common';
import { SmsProvider } from './sms-provider.interface';

@Injectable()
export class ConsoleSmsProvider implements SmsProvider {
  private readonly logger = new Logger(ConsoleSmsProvider.name);

  async sendSms(phone: string, message: string): Promise<void> {
    this.logger.log(`[SMS to ${phone}]: ${message}`);
  }
}
