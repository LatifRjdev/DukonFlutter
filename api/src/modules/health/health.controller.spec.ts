import { Test, TestingModule } from '@nestjs/testing';
import {
  HealthCheckService,
  PrismaHealthIndicator,
  HealthCheckError,
} from '@nestjs/terminus';

import { HealthController } from './health.controller';
import { PrismaService } from '../../prisma/prisma.service';

describe('HealthController', () => {
  let controller: HealthController;
  let healthCheck: jest.Mock;
  let pingCheck: jest.Mock;

  beforeEach(async () => {
    healthCheck = jest.fn(async (indicators: Array<() => Promise<any>>) => {
      const results: Record<string, any> = {};
      try {
        for (const fn of indicators) {
          Object.assign(results, await fn());
        }
        return { status: 'ok', info: results, error: {}, details: results };
      } catch (e) {
        const err = e as HealthCheckError;
        return {
          status: 'error',
          info: {},
          error: err.causes ?? { database: { status: 'down' } },
          details: err.causes ?? { database: { status: 'down' } },
        };
      }
    });

    pingCheck = jest.fn();

    const moduleRef: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        { provide: HealthCheckService, useValue: { check: healthCheck } },
        { provide: PrismaHealthIndicator, useValue: { pingCheck } },
        { provide: PrismaService, useValue: {} },
      ],
    }).compile();

    controller = moduleRef.get(HealthController);
  });

  it('should return ok status when DB ping succeeds', async () => {
    pingCheck.mockResolvedValue({ database: { status: 'up' } });

    const result = await controller.check();

    expect(pingCheck).toHaveBeenCalledWith('database', expect.anything());
    expect(result.status).toBe('ok');
    expect(result.details.database.status).toBe('up');
  });

  it('should return error status when DB ping throws', async () => {
    pingCheck.mockImplementation(() => {
      throw new HealthCheckError('DB down', {
        database: { status: 'down', message: 'connection refused' },
      });
    });

    const result = await controller.check();

    expect(result.status).toBe('error');
    expect(result.error?.database?.status).toBe('down');
  });
});
