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

  /**
   * Admin-to-admin impersonation is explicitly closed, not merely
   * unsupported by omission. A successful admin-to-admin impersonation
   * would hand the requesting admin a live, fully-privileged admin
   * session (not a scoped customer view) for the token's whole lifetime,
   * gated only on the target admin clicking "approve" on what looks like
   * a routine support-access prompt — a realistic social-engineering /
   * privilege-escalation path between admin accounts. This feature exists
   * for support access to *customer* accounts; reject before even
   * creating the request record so no PENDING request (and no push) is
   * ever generated for an admin target.
   */
  async request(adminId: string, targetUserId: string) {
    const targetUser = await this.prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, isAdmin: true },
    });
    if (!targetUser) throw new NotFoundException('Target user not found');
    if (targetUser.isAdmin) {
      throw new BadRequestException(
        'Cannot request impersonation access to an admin account',
      );
    }

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
    //
    // CRITICAL: the token's own TTL must be clamped to whatever remains
    // of the 30-minute approval window, NOT a flat 30m from the moment
    // issueToken() happens to be called. The check above only verifies
    // request.expiresAt hasn't passed *yet* — it doesn't bound how much
    // is left. Without this clamp, calling issueToken() at minute 29 of
    // the approval window would hand out a token good for a further 30
    // minutes from THAT call, up to ~60 minutes of total access from the
    // moment the customer approved — silently doubling the promised
    // "30 minutes, in any case" guarantee that is the entire point of
    // this consent-gated feature.
    const remainingMs = request.expiresAt.getTime() - Date.now();
    return this.jwt.sign(
      {
        sub: request.targetUserId,
        impersonatedBy: request.adminId,
        impersonationRequestId: request.id,
      },
      {
        secret: this.configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
        expiresIn: `${Math.max(1, Math.floor(remainingMs / 1000))}s`,
      },
    );
  }

  /**
   * Marks the request ENDED (blocking any *future* issueToken() call for
   * it — status is no longer APPROVED) AND immediately revokes the
   * target user's already-issued access token by bumping
   * User.tokensRevokedAt. This is the same mechanism used for password
   * changes (see UsersService.changePassword) and checked on every
   * request by JwtAccessStrategy.validate() ("F.1: reject any token
   * issued before the user's tokensRevokedAt") and JwtRefreshStrategy —
   * an already-proven, already-tested codepath, not a new one. Because
   * the impersonation token is signed with `sub: request.targetUserId`,
   * this causes the very next request made with it to be rejected.
   *
   * Tradeoff, intentional: bumping tokensRevokedAt for the target user
   * also invalidates THEIR OWN legitimate sessions (their real phone,
   * any other logged-in device) — they'll need to log back in. This is
   * accepted as correct, not worked around: ending an impersonation
   * session is a deliberate, security-conscious action (the support
   * agent clicking "end", or someone force-ending a session for safety),
   * and forcing a fresh re-login afterwards is a clean "everything is
   * revoked, please confirm you're back in control" boundary — exactly
   * the same UX this mechanism already produces after a password change.
   *
   * Left open to any admin, not just request.adminId — as a purely
   * protective action (it can only reduce access, never grant it) an
   * emergency "kill this session" should not be gated behind "were you
   * the one who started it".
   *
   * Guarded on request.status === 'APPROVED': without this, any admin
   * could POST /admin/users/:id/impersonate (creates a PENDING request —
   * no consent needed to create one) and immediately
   * POST /admin/impersonation/:id/end, force-revoking every live session
   * of an arbitrary target user who never approved anything. end() is
   * "stop an active session", not "force-logout any user via a request
   * they haven't responded to" — a PENDING or REJECTED request never
   * granted access in the first place, so there is nothing to revoke.
   */
  async end(requestId: string) {
    const request = await this.loadApprovedRequestOrThrow(requestId);
    return this.revokeApprovedRequest(request);
  }

  /**
   * Target-facing counterpart to end() (see ImpersonationController) — the
   * customer themselves ending their own active support session from
   * inside the app, rather than an admin ending it from the admin panel.
   * Must NOT reuse the admin-only /admin/impersonation/:id/end route:
   * that route is guarded by AdminGuard, and the impersonation token's
   * `sub` is the TARGET user (an ordinary customer in the realistic case,
   * not an admin), so AdminGuard would reject it every time.
   *
   * Two checks tie this to "the caller's own, currently-live impersonated
   * session, and no one else's":
   *  - callingUserId (from @CurrentUser('id'), i.e. request.user.id —
   *    populated by JwtAccessStrategy from the verified JWT's `sub`, not
   *    client-supplied) must equal request.targetUserId.
   *  - tokenImpersonationRequestId (from @CurrentUser('impersonationRequestId'),
   *    the impersonationRequestId claim JwtAccessStrategy surfaced from
   *    the presented token itself) must equal requestId. This is
   *    defense-in-depth beyond the first check — it confirms the caller
   *    is holding an impersonation token for THIS specific request, not
   *    just any token belonging to the same user id.
   */
  async endSelf(
    requestId: string,
    callingUserId: string,
    tokenImpersonationRequestId: string | undefined,
  ) {
    const request = await this.loadApprovedRequestOrThrow(requestId);
    if (
      request.targetUserId !== callingUserId ||
      tokenImpersonationRequestId !== requestId
    ) {
      throw new ForbiddenException('This session is not yours to end');
    }
    return this.revokeApprovedRequest(request);
  }

  private async loadApprovedRequestOrThrow(requestId: string) {
    const request = await this.prisma.impersonationRequest.findUnique({
      where: { id: requestId },
    });
    if (!request)
      throw new NotFoundException('Impersonation request not found');
    if (request.status !== 'APPROVED') {
      throw new BadRequestException(
        'This request was never approved — nothing to end',
      );
    }
    return request;
  }

  private async revokeApprovedRequest(request: {
    id: string;
    targetUserId: string;
  }) {
    const [updatedRequest] = await this.prisma.$transaction([
      this.prisma.impersonationRequest.update({
        where: { id: request.id },
        data: { status: 'ENDED', endedAt: new Date() },
      }),
      this.prisma.user.update({
        where: { id: request.targetUserId },
        data: { tokensRevokedAt: new Date() },
      }),
    ]);

    return updatedRequest;
  }
}
