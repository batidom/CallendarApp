import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

/// Registered globally (see main.ts) so every unhandled error goes through
/// one place instead of relying on Nest's built-in default. HttpExceptions
/// (validation errors, "Incorrect password", ApiException-shaped 4xx/403s,
/// ...) already carry a deliberate, safe-to-show message and pass through
/// unchanged — everything else is an unexpected bug, so the client only
/// ever sees a generic message for those, never a raw stack trace or an
/// internal error string, while the real detail is still logged server-side
/// for debugging.
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const isHttpException = exception instanceof HttpException;
    const status = isHttpException
      ? exception.getStatus()
      : HttpStatus.INTERNAL_SERVER_ERROR;
    const body = isHttpException
      ? exception.getResponse()
      : { statusCode: status, message: 'Internal server error' };

    if (!isHttpException) {
      this.logger.error(
        `Unhandled exception on ${request.method} ${request.url}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    response.status(status).json(body);
  }
}
