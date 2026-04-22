import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import { PrismaService } from '../../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { OtpService } from './otp.service';
import { OtpType } from '@prisma/client';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
    private otpService: OtpService,
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });

    if (existing) {
      throw new ConflictException('User with this phone already exists');
    }

    const hashedPassword = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.user.create({
      data: {
        phone: dto.phone,
        password: hashedPassword,
        name: dto.name,
        email: dto.email,
      },
    });

    const tokens = await this.generateTokens(user.id, user.phone);
    return {
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        email: user.email,
      },
      ...tokens,
    };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid phone or password');
    }

    if (!user.isActive) {
      throw new UnauthorizedException('Account is deactivated');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid phone or password');
    }

    const tokens = await this.generateTokens(user.id, user.phone);
    return {
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        email: user.email,
      },
      ...tokens,
    };
  }

  async refresh(userId: string, phone: string, oldTokenId: string) {
    // Rotate in a single transaction so a partial failure can never leave
    // the user with zero valid refresh tokens OR leave the old row alive
    // after a new one was issued (BE-P1-001).
    //
    // Replay detection: if the deleted row count is zero the presented jti
    // did not exist — either already used or revoked via logout. Either
    // way we refuse the refresh AND burn every remaining token for this
    // user as a safety net so an attacker cannot keep rotating in parallel
    // with the real user.
    return this.prisma.$transaction(async (tx) => {
      const deleted = await tx.refreshToken.deleteMany({
        where: { token: oldTokenId, userId },
      });
      if (deleted.count === 0) {
        await tx.refreshToken.deleteMany({ where: { userId } });
        throw new UnauthorizedException(
          'Refresh token replay detected — all sessions revoked',
        );
      }
      return this.issueTokens(tx, userId, phone);
    });
  }

  async logout(userId: string, refreshTokenJti?: string) {
    if (refreshTokenJti) {
      await this.prisma.refreshToken.deleteMany({
        where: { token: refreshTokenJti, userId },
      });
    } else {
      await this.prisma.refreshToken.deleteMany({
        where: { userId },
      });
    }
  }

  /**
   * Nuke every refresh token for the given user, kicking every active
   * session at once. Used by the logout-all endpoint — e.g. after the
   * user notices suspicious activity or changes their password
   * (BE-P1-002).
   */
  async logoutAll(userId: string) {
    await this.prisma.refreshToken.deleteMany({ where: { userId } });
  }

  async sendOtp(phone: string) {
    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) {
      throw new BadRequestException('Пользователь с таким номером не найден');
    }
    await this.otpService.sendOtp(phone, OtpType.VERIFY);
    return { message: 'Код отправлен' };
  }

  async verifyOtp(phone: string, code: string) {
    await this.otpService.verifyOtp(phone, code, OtpType.VERIFY);
    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) {
      throw new BadRequestException('Пользователь с таким номером не найден');
    }
    return this.generateTokens(user.id, user.phone);
  }

  async forgotPassword(phone: string) {
    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) {
      throw new BadRequestException('Пользователь с таким номером не найден');
    }
    await this.otpService.sendOtp(phone, OtpType.RESET);
    return { message: 'Код для сброса пароля отправлен' };
  }

  async resetPassword(phone: string, code: string, newPassword: string) {
    await this.otpService.verifyOtp(phone, code, OtpType.RESET);
    const hashed = await bcrypt.hash(newPassword, 12);
    await this.prisma.user.update({
      where: { phone },
      data: { password: hashed },
    });
    return { message: 'Пароль успешно изменён' };
  }

  private async generateTokens(userId: string, phone: string) {
    return this.issueTokens(this.prisma, userId, phone);
  }

  /**
   * Issue a new access+refresh pair and persist the refresh jti.
   *
   * Accepts any Prisma transaction client so the refresh rotation path can
   * delete the old row + insert the new row atomically — see refresh().
   *
   * Refresh expiry shrunk from 30d to 7d (BE-P1-002). Access is 15m.
   */
  private async issueTokens(
    tx: Pick<PrismaService, 'refreshToken'>,
    userId: string,
    phone: string,
  ) {
    const jti = uuidv4();

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(
        { sub: userId, phone },
        {
          secret: this.configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
          expiresIn: '15m',
        },
      ),
      this.jwtService.signAsync(
        { sub: userId, phone, jti },
        {
          secret: this.configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
          expiresIn: '7d',
        },
      ),
    ]);

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    await tx.refreshToken.create({
      data: {
        token: jti,
        userId,
        expiresAt,
      },
    });

    return { accessToken, refreshToken };
  }
}
