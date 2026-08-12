import { ConflictException } from '@nestjs/common';

export class RetryableConflictException extends ConflictException {
  constructor(
    message: string,
    public readonly retryAfterSeconds: number = 5,
  ) {
    super(message);
  }
}
