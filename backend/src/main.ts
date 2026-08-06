import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.useGlobalFilters(new AllExceptionsFilter());
  app.use(helmet());

  // The shipped clients (Windows/Android) aren't browsers, so CORS doesn't
  // constrain them — this only matters if something browser-based (a future
  // web client, Swagger UI, etc.) talks to the API directly. Comma-separated
  // ALLOWED_ORIGINS restricts that; unset stays permissive for local dev,
  // but a production deploy with CORS wide open to any origin is a real
  // security gap, so it fails fast at startup instead of silently shipping
  // that way.
  const isProduction = process.env.NODE_ENV === 'production';
  const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',').map((origin) =>
    origin.trim(),
  );
  if (isProduction && !allowedOrigins) {
    throw new Error(
      'ALLOWED_ORIGINS must be set when NODE_ENV=production — refusing to start with CORS open to any origin.',
    );
  }
  app.enableCors({ origin: allowedOrigins ?? true });

  await app.listen(process.env.PORT ?? 3000);
}

void bootstrap();
