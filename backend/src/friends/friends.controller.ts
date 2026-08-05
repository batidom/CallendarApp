import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AuthenticatedUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { SearchUsersDto } from './dto/search-users.dto';
import { SendFriendRequestDto } from './dto/send-friend-request.dto';
import { FriendsService } from './friends.service';

@UseGuards(JwtAuthGuard)
@Controller('friends')
export class FriendsController {
  constructor(private readonly friendsService: FriendsService) {}

  @Get('search')
  search(@CurrentUser() user: AuthenticatedUser, @Query() query: SearchUsersDto) {
    return this.friendsService.search(user.id, query.q);
  }

  @Get()
  listFriends(@CurrentUser() user: AuthenticatedUser) {
    return this.friendsService.listFriends(user.id);
  }

  @Delete(':userId')
  removeFriend(@CurrentUser() user: AuthenticatedUser, @Param('userId') userId: string) {
    return this.friendsService.removeFriend(user.id, userId);
  }

  @Get('requests/incoming')
  listIncoming(@CurrentUser() user: AuthenticatedUser) {
    return this.friendsService.listIncomingRequests(user.id);
  }

  @Get('requests/outgoing')
  listOutgoing(@CurrentUser() user: AuthenticatedUser) {
    return this.friendsService.listOutgoingRequests(user.id);
  }

  @Post('requests')
  sendRequest(@CurrentUser() user: AuthenticatedUser, @Body() dto: SendFriendRequestDto) {
    return this.friendsService.sendRequest(user.id, dto.username);
  }

  @Post('requests/:id/accept')
  acceptRequest(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.friendsService.acceptRequest(user.id, id);
  }

  @Post('requests/:id/decline')
  declineRequest(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.friendsService.declineRequest(user.id, id);
  }

  @Delete('requests/:id')
  cancelRequest(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.friendsService.cancelRequest(user.id, id);
  }
}
