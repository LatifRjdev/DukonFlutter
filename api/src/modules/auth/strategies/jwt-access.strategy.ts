import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../../prisma/prisma.service';

@Injectable()
export class JwtAccessStrategy extends PassportStrategy(
  Strategy,
  'jwt-access',
) {
  constructor(
    configService: ConfigService,
    private prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
    });
  }

  async validate(payload: { sub: string; phone: string; iat?: number }) {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: {
        id: true,
        phone: true,
        name: true,
        isActive: true,
        isAdmin: true,
        tokensRevokedAt: true,
      },
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or inactive');
    }

    // F.1: reject any token issued before the user's tokensRevokedAt.
    // JWT `iat` is in seconds, tokensRevokedAt is millisecond-precision.
    if (user.tokensRevokedAt && payload.iat) {
      const revokedAtSec = Math.floor(user.tokensRevokedAt.getTime() / 1000);
      if (payload.iat <= revokedAtSec) {
        throw new UnauthorizedException(
          'Token revoked. Please sign in again.',
        );
      }
    }

    return {
      id: user.id,
      phone: user.phone,
      name: user.name,
      isAdmin: user.isAdmin,
    };
  }
}
