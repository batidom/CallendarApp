import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // The shipped clients (Windows/Android) aren't browsers, so CORS doesn't
  // constrain them — this only matters if something browser-based (a future
  // web client, Swagger UI, etc.) talks to the API directly. Comma-separated
  // ALLOWED_ORIGINS restricts that; unset stays permissive for local dev.
  const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',').map((origin) => origin.trim());
  app.enableCors({ origin: allowedOrigins ?? true });

  await app.listen(process.env.PORT ?? 3000);
}

void bootstrap();
