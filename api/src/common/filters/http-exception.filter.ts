import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { RetryableConflictException } from '../exceptions/retryable-conflict.exception';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);
  private readonly isProduction = process.env.NODE_ENV === 'production';

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | string[] = 'Internal server error';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();
      if (typeof exceptionResponse === 'string') {
        message = exceptionResponse;
      } else if (exceptionResponse && typeof exceptionResponse === 'object') {
        const body = exceptionResponse as { message?: string | string[] };
        message = body.message ?? message;
      }
    }

    // Log every 4xx and 5xx server-side.
    //
    // 4xx used to be logged NOWHERE: LoggingInterceptor only logs the success
    // path (its tap() has no error callback), and NestJS runs guards before
    // interceptors, so a guard rejection never reaches it at all. A 403 from
    // StoreAccessGuard therefore left no trace, and an empty log reads like
    // "nothing was denied" — which is how a cross-store access bug went
    // misdiagnosed for half an hour.
    //
    // 4xx is warn with no stack: it is an expected outcome, and a stack would
    // bury the one line you actually want to grep. 5xx keeps error + stack
    // off-production so prod logs stay terse without losing the detail in dev.
    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      const stack =
        exception instanceof Error ? exception.stack : String(exception);
      this.logger.error(
        `${request.method} ${request.url} -> ${status}`,
        this.isProduction ? undefined : stack,
      );
    } else if (status >= HttpStatus.BAD_REQUEST) {
      this.logger.warn(`${request.method} ${request.url} -> ${status}`);
    }

    // Never leak raw exception messages (Prisma column names, stack fragments,
    // ORM internals) to clients on 5xx — always respond with a generic body.
    const responseMessage =
      status >= HttpStatus.INTERNAL_SERVER_ERROR
        ? ['Internal server error']
        : Array.isArray(message)
          ? message
          : [message];

    if (exception instanceof RetryableConflictException) {
      response.setHeader('Retry-After', String(exception.retryAfterSeconds));
    }

    response.status(status).json({
      statusCode: status,
      message: responseMessage,
      timestamp: new Date().toISOString(),
      path: request.url,
    });
  }
}
