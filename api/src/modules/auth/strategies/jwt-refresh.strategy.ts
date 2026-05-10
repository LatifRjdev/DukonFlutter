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

  async validate(payload: {
    sub: string;
    phone: string;
    jti: string;
    iat?: number;
  }) {
    const token = await this.prisma.refreshToken.findFirst({
      where: { userId: payload.sub, token: payload.jti },
    });

    if (!token || token.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token expired or invalid');
    }

    // F.1: same revocation check as the access strategy. After
    // password change, refresh tokens issued before the rotation
    // also stop working — forcing the user to log in again.
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: { tokensRevokedAt: true },
    });
    if (user?.tokensRevokedAt && payload.iat) {
      const revokedAtSec = Math.floor(user.tokensRevokedAt.getTime() / 1000);
      if (payload.iat <= revokedAtSec) {
        throw new UnauthorizedException(
          'Token revoked. Please sign in again.',
        );
      }
    }

    return { id: payload.sub, phone: payload.phone, tokenId: payload.jti };
  }
}
