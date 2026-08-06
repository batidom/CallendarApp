import { Controller, Get } from '@nestjs/common';

@Controller()
export class AppController {
  // Used by the uptime monitor and Docker's own healthcheck — deliberately
  // has no dependencies (no DB ping) so it stays fast and can't itself
  // become a source of false alarms; a DB outage already surfaces through
  // every other endpoint failing.
  @Get('health')
  health() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }
}
