import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { AuthenticatedUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { EventInvitesService } from './event-invites.service';
import { InviteToEventDto } from './dto/invite-to-event.dto';
import { RespondToInviteDto } from './dto/respond-to-invite.dto';

@UseGuards(JwtAuthGuard)
@Controller('events')
export class EventInvitesController {
  constructor(private readonly eventInvitesService: EventInvitesService) {}

  @Get('invites/pending')
  listMyPendingInvites(@CurrentUser() user: AuthenticatedUser) {
    return this.eventInvitesService.listMyPendingInvites(user.id);
  }

  @Post('invites/:inviteId/respond')
  respond(
    @CurrentUser() user: AuthenticatedUser,
    @Param('inviteId') inviteId: string,
    @Body() dto: RespondToInviteDto,
  ) {
    return this.eventInvitesService.respond(user.id, inviteId, dto.accept);
  }

  @Get(':id/invites')
  list(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.eventInvitesService.list(user.id, id);
  }

  @Post(':id/invites')
  invite(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: InviteToEventDto,
  ) {
    return this.eventInvitesService.invite(user.id, id, dto);
  }

  @Delete(':id/invites/:inviteId')
  revoke(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Param('inviteId') inviteId: string,
  ) {
    return this.eventInvitesService.revoke(user.id, id, inviteId);
  }

  @Post(':id/leave')
  async leave(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    await this.eventInvitesService.leave(user.id, id);
    return {};
  }
}
