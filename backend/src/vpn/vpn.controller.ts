import {
  Controller,
  Get,
  Post,
  Param,
  Delete,
  Body,
  Patch,
} from '@nestjs/common';
import { VpnService } from './vpn.service';

@Controller('vpn')
export class VpnController {
  constructor(private readonly vpnService: VpnService) {}

  @Post('users/:userId/peers')
  async createPeer(@Param('userId') userId: string) {
    return this.vpnService.createPeer(userId);
  }

  @Get('users/:userId/peers')
  async getUserPeers(@Param('userId') userId: string) {
    return this.vpnService.getUserPeers(userId);
  }

  @Get('peers/:peerId/config')
  async getPeerConfig(@Param('peerId') peerId: string) {
    const config = await this.vpnService.getPeerConfig(peerId);
    return { config };
  }

  @Patch('peers/:peerId/deactivate')
  async deactivatePeer(
    @Param('peerId') peerId: string,
    @Body() body: { userId?: string },
  ) {
    await this.vpnService.deactivatePeer(peerId, body.userId);
    return { message: 'Peer deactivated' };
  }

  @Patch('peers/:peerId/activate')
  async activatePeer(
    @Param('peerId') peerId: string,
    @Body() body: { userId?: string },
  ) {
    await this.vpnService.activatePeer(peerId, body.userId);
    return { message: 'Peer activated' };
  }

  @Delete('peers/:peerId')
  async deletePeer(
    @Param('peerId') peerId: string,
    @Body() body: { userId?: string },
  ) {
    await this.vpnService.deactivatePeer(peerId, body.userId);
    return { message: 'Peer deleted' };
  }

  @Post('peers/:peerId/migrate')
  async migratePeer(
    @Param('peerId') peerId: string,
    @Body() body: { serverId: string },
  ) {
    const result = await this.vpnService.migratePeerToServer(peerId, body.serverId);
    return {
      message: 'Peer migrated successfully',
      peer: result.peer,
      config: result.config,
    };
  }
}

