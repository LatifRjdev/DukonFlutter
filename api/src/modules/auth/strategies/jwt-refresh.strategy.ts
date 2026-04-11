import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../../prisma/prisma.service';

@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(Strategy, 'jwt-refresh') {
  constructor(
    configService: ConfigService,
    private prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromBodyField('refreshToken'),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
    });
  }

  async validate(payload: { sub: string; phone: string; jti: string }) {
    const token = await this.prisma.refreshToken.findFirst({
      where: { userId: payload.sub, token: payload.jti },
    });

    if (!token || token.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token expired or invalid');
    }

    return { id: payload.sub, phone: payload.phone, tokenId: payload.jti };
  }
}
