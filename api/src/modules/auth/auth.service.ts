import { Injectable, ConflictException, UnauthorizedException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import { PrismaService } from '../../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
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
      user: { id: user.id, phone: user.phone, name: user.name, email: user.email },
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
      user: { id: user.id, phone: user.phone, name: user.name, email: user.email },
      ...tokens,
    };
  }

  async refresh(userId: string, phone: string, oldTokenId: string) {
    // Delete old refresh token (rotation)
    await this.prisma.refreshToken.deleteMany({
      where: { token: oldTokenId },
    });

    const tokens = await this.generateTokens(userId, phone);
    return tokens;
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

  private async generateTokens(userId: string, phone: string) {
    const jti = uuidv4();

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(
        { sub: userId, phone },
        {
          secret: this.configService.get<string>('JWT_ACCESS_SECRET', 'access-secret-dev'),
          expiresIn: '15m',
        },
      ),
      this.jwtService.signAsync(
        { sub: userId, phone, jti },
        {
          secret: this.configService.get<string>('JWT_REFRESH_SECRET', 'refresh-secret-dev'),
          expiresIn: '30d',
        },
      ),
    ]);

    // Store refresh token in DB
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await this.prisma.refreshToken.create({
      data: {
        token: jti,
        userId,
        expiresAt,
      },
    });

    return { accessToken, refreshToken };
  }
}
