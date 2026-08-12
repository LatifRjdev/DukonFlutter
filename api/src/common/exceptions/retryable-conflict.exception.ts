import { ConflictException } from '@nestjs/common';

/**
 * A 409 conflict that the caller can reasonably expect to succeed on retry,
 * because it was caused by a transient race rather than by a permanently
 * invalid request.
 *
 * Throw this ONLY when retrying the exact same request has a real chance of
 * succeeding without the caller changing anything — e.g. an atomic
 * conditional-updateMany stock guard that lost a race with a concurrent sale.
 * Keep using the plain `ConflictException` for conflicts that are stable
 * facts about the system's state (staff member already exists, phone already
 * registered, shift already open): those will fail identically on every
 * retry, and advertising a Retry-After there actively misleads clients into
 * pointless retry loops.
 *
 * `AllExceptionsFilter` translates this — and only this subclass — into a
 * `Retry-After: <retryAfterSeconds>` response header.
 */
export class RetryableConflictException extends ConflictException {
  constructor(
    message: string,
    public readonly retryAfterSeconds: number = 5,
  ) {
    super(message);
  }
}
