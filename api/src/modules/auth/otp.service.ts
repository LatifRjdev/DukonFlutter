import { Injectable, BadRequestException, Inject } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { OtpType } from '@prisma/client';
import { SmsProvider, SMS_PROVIDER } from './sms-provider.interface';

@Injectable()
export class OtpService {
  constructor(
    private prisma: PrismaService,
    @Inject(SMS_PROVIDER) private smsProvider: SmsProvider,
  ) {}

  async sendOtp(phone: string, type: OtpType): Promise<void> {
    const recentCount = await this.prisma.otpCode.count({
      where: {
        phone,
        type,
        createdAt: { gte: new Date(Date.now() - 60_000) },
      },
    });

    if (recentCount >= 3) {
      throw new BadRequestException(
        'Слишком много запросов. Попробуйте через минуту.',
      );
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 60_000);

    await this.prisma.otpCode.create({
      data: { phone, code, type, expiresAt },
    });

    await this.smsProvider.sendSms(
      phone,
      `DukonPro: Ваш код подтверждения: ${code}`,
    );
  }

  async verifyOtp(
    phone: string,
    code: string,
    type: OtpType,
  ): Promise<boolean> {
    const otp = await this.prisma.otpCode.findFirst({
      where: {
        phone,
        code,
        type,
        used: false,
        expiresAt: { gte: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) {
      throw new BadRequestException('Неверный или истёкший код');
    }

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { used: true },
    });

    return true;
  }
}
