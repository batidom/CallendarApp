import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuthenticatedUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { NotificationsService } from './notifications.service';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  list(@CurrentUser() user: AuthenticatedUser) {
    return this.notificationsService.list(user.id);
  }
}
