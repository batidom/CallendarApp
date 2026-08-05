import { Body, Controller, Delete, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { AuthenticatedUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AddGroupMemberDto } from './dto/add-group-member.dto';
import { CreateGroupDto } from './dto/create-group.dto';
import { GroupsService } from './groups.service';

@UseGuards(JwtAuthGuard)
@Controller('groups')
export class GroupsController {
  constructor(private readonly groupsService: GroupsService) {}

  @Get()
  list(@CurrentUser() user: AuthenticatedUser) {
    return this.groupsService.listGroups(user.id);
  }

  @Get('memberships')
  listMemberships(@CurrentUser() user: AuthenticatedUser) {
    return this.groupsService.listMemberships(user.id);
  }

  @Post()
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateGroupDto) {
    return this.groupsService.createGroup(user.id, dto.name);
  }

  @Put(':id')
  rename(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: CreateGroupDto,
  ) {
    return this.groupsService.renameGroup(user.id, id, dto.name);
  }

  @Delete(':id')
  remove(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.groupsService.deleteGroup(user.id, id);
  }

  @Post(':id/members')
  addMember(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AddGroupMemberDto,
  ) {
    return this.groupsService.addMember(user.id, id, dto.userId);
  }

  @Delete(':id/members/:userId')
  removeMember(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Param('userId') userId: string,
  ) {
    return this.groupsService.removeMember(user.id, id, userId);
  }
}
