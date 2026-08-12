import {
  ArgumentsHost,
  ConflictException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { AllExceptionsFilter } from './http-exception.filter';
import { RetryableConflictException } from '../exceptions/retryable-conflict.exception';

// Regression tests for BE-P0-004: the filter previously copied raw
// exception messages into 5xx responses (leaking Prisma column names and
// stack fragments). These tests lock down the generic 'Internal server
// error' body for any non-HttpException or 5xx path.

function makeHost(): {
  host: ArgumentsHost;
  response: {
    statusCode: number;
    body: unknown;
    headers: Record<string, string>;
  };
  request: { method: string; url: string };
} {
  const response = {
    statusCode: 0,
    body: undefined as unknown,
    headers: {} as Record<string, string>,
  };
  const request = { method: 'GET', url: '/api/test' };
  const mockResponse = {
    status(code: number) {
      response.statusCode = code;
      return this;
    },
    setHeader(name: string, value: string) {
      response.headers[name] = value;
      return this;
    },
    json(body: unknown) {
      response.body = body;
      return this;
    },
  };
  const host = {
    switchToHttp: () => ({
      getResponse: () => mockResponse,
      getRequest: () => request,
    }),
  } as unknown as ArgumentsHost;
  return { host, response, request };
}

describe('AllExceptionsFilter', () => {
  let filter: AllExceptionsFilter;

  beforeEach(() => {
    filter = new AllExceptionsFilter();
    // Silence Logger.error so test output stays readable.
    jest
      .spyOn(
        (filter as unknown as { logger: { error: jest.Mock } }).logger,
        'error',
      )
      .mockImplementation(() => undefined);
  });

  describe('HttpException (4xx)', () => {
    it('passes through the HttpException status and message', () => {
      const { host, response } = makeHost();
      filter.catch(
        new HttpException('User not found', HttpStatus.NOT_FOUND),
        host,
      );
      expect(response.statusCode).toBe(404);
      const body = response.body as {
        statusCode: number;
        message: string[];
      };
      expect(body.statusCode).toBe(404);
      expect(body.message).toEqual(['User not found']);
    });

    it('unwraps ValidationPipe shape { message, error }', () => {
      const { host, response } = makeHost();
      filter.catch(
        new HttpException(
          { message: ['name should not be empty'], error: 'Bad Request' },
          HttpStatus.BAD_REQUEST,
        ),
        host,
      );
      expect(response.statusCode).toBe(400);
      const body = response.body as { message: string[] };
      expect(body.message).toEqual(['name should not be empty']);
    });
  });

  describe('Non-HttpException (5xx)', () => {
    it('returns generic Internal server error, never the raw message', () => {
      const { host, response } = makeHost();
      filter.catch(
        new Error(
          'PostgresError: column "users.secret_internal_field" does not exist',
        ),
        host,
      );
      expect(response.statusCode).toBe(500);
      const body = response.body as { message: string[] };
      expect(body.message).toEqual(['Internal server error']);
      expect(JSON.stringify(body).includes('PostgresError')).toBe(false);
      expect(JSON.stringify(body).includes('secret_internal_field')).toBe(
        false,
      );
    });

    it('handles non-Error thrown values safely', () => {
      const { host, response } = makeHost();
      filter.catch('just a string', host);
      expect(response.statusCode).toBe(500);
      const body = response.body as { message: string[] };
      expect(body.message).toEqual(['Internal server error']);
    });

    it('handles null thrown', () => {
      const { host, response } = makeHost();
      filter.catch(null, host);
      expect(response.statusCode).toBe(500);
      const body = response.body as { message: string[] };
      expect(body.message).toEqual(['Internal server error']);
    });
  });

  describe('5xx HttpException', () => {
    it('still returns the generic body (no leaking internal text)', () => {
      const { host, response } = makeHost();
      filter.catch(
        new HttpException(
          'database timeout on shard 7',
          HttpStatus.INTERNAL_SERVER_ERROR,
        ),
        host,
      );
      const body = response.body as { message: string[] };
      expect(body.message).toEqual(['Internal server error']);
      expect(JSON.stringify(body).includes('database timeout')).toBe(false);
    });

    it('502 returned as generic', () => {
      const { host, response } = makeHost();
      filter.catch(
        new HttpException('upstream dead', HttpStatus.BAD_GATEWAY),
        host,
      );
      expect(response.statusCode).toBe(502);
      const body = response.body as { message: string[] };
      expect(body.message).toEqual(['Internal server error']);
    });
  });

  describe('response envelope', () => {
    it('always includes statusCode, message[], timestamp, path', () => {
      const { host, response } = makeHost();
      filter.catch(new HttpException('boom', HttpStatus.BAD_REQUEST), host);
      const body = response.body as Record<string, unknown>;
      expect(body.statusCode).toBe(400);
      expect(Array.isArray(body.message)).toBe(true);
      expect(typeof body.timestamp).toBe('string');
      expect(body.path).toBe('/api/test');
    });
  });

  it('should set a Retry-After header when a RetryableConflictException is thrown', () => {
    const { host, response } = makeHost();
    filter.catch(
      new RetryableConflictException('Stock changed concurrently', 7),
      host,
    );
    expect(response.headers['Retry-After']).toBe('7');
    expect(response.statusCode).toBe(409);
  });

  it('should NOT set a Retry-After header for a plain ConflictException', () => {
    const { host, response } = makeHost();
    filter.catch(new ConflictException('Staff member already exists'), host);
    expect(response.headers['Retry-After']).toBeUndefined();
    expect(response.statusCode).toBe(409);
  });
});
