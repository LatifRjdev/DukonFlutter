import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import compression from 'compression';
import cookieParser from 'cookie-parser';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { validateBootConfig } from './common/bootstrap/validate-config';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);

  const configService = app.get(ConfigService);

  // Fail-fast on misconfigured secrets / missing CORS in production
  // (BE-P1-005 / BE-P1-007).
  validateBootConfig(configService);

  // Global prefix
  app.setGlobalPrefix('api');

  // Security — explicit CSP / HSTS rather than helmet defaults (BE-P1-006).
  // The API is headless so a strict default-src 'none' is safe; Swagger UI
  // is the one exception that loads its own JS/CSS from /api/docs.
  app.use(
    helmet({
      contentSecurityPolicy: {
        useDefaults: false,
        directives: {
          defaultSrc: ["'none'"],
          baseUri: ["'none'"],
          frameAncestors: ["'none'"],
          // Swagger UI served from this origin — allow self.
          scriptSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", 'data:'],
          connectSrc: ["'self'"],
          fontSrc: ["'self'"],
        },
      },
      hsts: {
        maxAge: 15552000, // 180 days
        includeSubDomains: true,
        preload: true,
      },
      referrerPolicy: { policy: 'no-referrer' },
      crossOriginOpenerPolicy: { policy: 'same-origin' },
      crossOriginResourcePolicy: { policy: 'same-origin' },
    }),
  );
  app.use(compression());
  app.use(cookieParser());

  // CORS — whitelist parsed from CORS_ORIGIN (comma-separated). In
  // development, fall back to any localhost origin. In production,
  // validateBootConfig already guarantees CORS_ORIGIN is explicit.
  const rawCorsOrigin = configService.get<string>('CORS_ORIGIN');
  const nodeEnv = configService.get<string>('NODE_ENV', 'development');
  const allowedOrigins = rawCorsOrigin
    ? rawCorsOrigin.split(',').map((s) => s.trim()).filter(Boolean)
    : [];
  type CorsOriginCallback = (
    err: Error | null,
    allow?: boolean,
  ) => void;
  app.enableCors({
    origin: (origin: string | undefined, callback: CorsOriginCallback) => {
      // Allow server-to-server / curl (no Origin header)
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      if (
        nodeEnv !== 'production' &&
        /^https?:\/\/localhost(:\d+)?$/.test(origin)
      ) {
        return callback(null, true);
      }
      return callback(new Error(`Origin ${origin} not allowed by CORS`));
    },
    credentials: true,
  });

  // Global pipes, filters, interceptors
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());
  app.useGlobalInterceptors(new LoggingInterceptor(), new TransformInterceptor());

  // Swagger
  const swaggerConfig = new DocumentBuilder()
    .setTitle('DokonPro API')
    .setDescription('API для управления розничными магазинами')
    .setVersion('1.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);

  const port = configService.get<number>('PORT', 3000);
  await app.listen(port);
  logger.log(`Application running on port ${port}`);
  logger.log(`Swagger: http://localhost:${port}/api/docs`);
}
bootstrap();
