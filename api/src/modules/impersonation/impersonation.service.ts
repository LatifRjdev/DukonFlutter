import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

const IMPERSONATION_SESSION_MINUTES = 30;

@Injectable()
export class ImpersonationService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private jwt: JwtService,
    private configService: ConfigService,
  ) {}

  async request(adminId: string, targetUserId: string) {
    const request = await this.prisma.impersonationRequest.create({
      data: { adminId, targetUserId, status: 'PENDING' },
    });

    // storeId is not required here — sendPush needs one, so we look up the
    // target's oldest store the same way sendDirectNotification-style flows
    // elsewhere in the app do. If the target user owns no store we simply
    // skip the push — the request record still exists and can be approved
    // from the in-app notifications/requests list once they have context.
    const store = await this.prisma.store.findFirst({
      where: { ownerId: targetUserId },
      select: { id: true },
      orderBy: { createdAt: 'asc' },
    });
    if (store) {
      await this.notifications.sendPush(
        targetUserId,
        'Запрос доступа от поддержки',
        'Поддержка Dukon запросила временный доступ к вашему аккаунту для диагностики. Откройте приложение, чтобы разрешить или отклонить.',
        'IMPERSONATION_REQUEST',
        store.id,
      );
    }

    return request;
  }

  /**
   * The Notification record created by request() carries only
   * { type: 'IMPERSONATION_REQUEST', title, body } — there's no
   * structured-data field on the Notification model to smuggle the
   * request id through the push/notifications-list payload. So the
   * mobile consent flow looks the pending request up directly by the
   * responding user's own id instead of needing an id passed in.
   */
  async findPendingForUser(targetUserId: string) {
    return this.prisma.impersonationRequest.findFirst({
      where: { targetUserId, status: 'PENDING' },
      orderBy: { requestedAt: 'desc' },
    });
  }

  async respond(
    requestId: string,
    respondingUserId: string,
    decision: 'APPROVED' | 'REJECTED',
  ) {
    const request = await this.prisma.impersonationRequest.findUnique({
      where: { id: requestId },
    });
    if (!request)
      throw new NotFoundException('Impersonation request not found');
    if (request.targetUserId !== respondingUserId) {
      throw new BadRequestException(
        'This request does not belong to the current user',
      );
    }
    if (request.status !== 'PENDING') {
      throw new BadRequestException(
        'This request has already been responded to',
      );
    }

    const respondedAt = new Date();
    const expiresAt =
      decision === 'APPROVED'
        ? new Date(
            respondedAt.getTime() + IMPERSONATION_SESSION_MINUTES * 60000,
          )
        : undefined;

    return this.prisma.impersonationRequest.update({
      where: { id: requestId },
      data: { status: decision, respondedAt, expiresAt },
    });
  }

  /**
   * @param callingAdminId The admin making THIS request (from the verified
   *   JWT via @CurrentUser, not a client-supplied value) — must match
   *   request.adminId. Without this check, any admin account could pull
   *   the token for a request another admin initiated (request ids are
   *   UUIDs, not secrets, and are visible in this admin's own audit-log
   *   entries), silently gaining a live session as the target user while
   *   the audit trail's viaImpersonation record still points at the
   *   original requester.
   */
  async issueToken(requestId: string, callingAdminId: string): Promise<string> {
    const request = await this.prisma.impersonationRequest.findUnique({
      where: { id: requestId },
    });
    if (!request)
      throw new NotFoundException('Impersonation request not found');
    if (request.status !== 'APPROVED') {
      throw new BadRequestException('Request is not approved');
    }
    if (!request.expiresAt || request.expiresAt < new Date()) {
      throw new BadRequestException(
        'Approval has expired — request access again',
      );
    }
    if (request.adminId !== callingAdminId) {
      throw new ForbiddenException(
        'This impersonation request was not created by you',
      );
    }

    // Signed with the SAME secret (JWT_ACCESS_SECRET) and looked up the
    // same way as normal login tokens — see AuthService.issueTokens() and
    // JwtAccessStrategy. JwtAccessStrategy.validate() only reads
    // payload.sub (to re-fetch the user) and payload.iat (for the
    // tokensRevokedAt check); it does not otherwise validate payload
    // shape, so the extra impersonatedBy/impersonationRequestId claims
    // ride along safely and are surfaced onto request.user by the
    // strategy (see jwt-access.strategy.ts).
    return this.jwt.sign(
      {
        sub: request.targetUserId,
        impersonatedBy: request.adminId,
        impersonationRequestId: request.id,
      },
      {
        secret: this.configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
        expiresIn: '30m',
      },
    );
  }

  /**
   * Marks the request ENDED, which stops any *future* issueToken() call
   * for this request (status is no longer APPROVED). It does NOT revoke a
   * JWT that was already handed out before end() was called — JwtAuthGuard
   * / JwtAccessStrategy never re-checks ImpersonationRequest.status on
   * subsequent requests, so an already-issued token keeps working until
   * its own `exp` (max 30 minutes from when it was signed). Deliberately
   * left open to any admin, not just request.adminId — as a purely
   * protective action (it can only reduce access, never grant it) an
   * emergency "kill this session" should not be gated behind "were you
   * the one who started it".
   */
  async end(requestId: string) {
    const request = await this.prisma.impersonationRequest.findUnique({
      where: { id: requestId },
    });
    if (!request)
      throw new NotFoundException('Impersonation request not found');

    return this.prisma.impersonationRequest.update({
      where: { id: requestId },
      data: { status: 'ENDED', endedAt: new Date() },
    });
  }
}
