import { Controller, Get, Post, Body, Param, Delete } from '@nestjs/common';
import { WireguardService } from './wireguard.service';

@Controller('wireguard')
export class WireguardController {
  constructor(private readonly wireguardService: WireguardService) {}

  @Get('servers')
  async getServers() {
    return this.wireguardService.findAllServers();
  }

  @Get('servers/:id')
  async getServer(@Param('id') id: string) {
    return this.wireguardService.findServerById(id);
  }

  @Post('servers')
  async createServer(@Body() serverData: {
    name: string;
    host: string;
    port: number;
    publicIp: string;
    privateIp: string;
    endpoint: string;
    network: string;
    dns?: string;
    publicKey?: string;
    privateKey?: string;
  }) {
    return this.wireguardService.createServer(serverData);
  }

  @Post('servers/:serverId/peers')
  async addPeer(
    @Param('serverId') serverId: string,
    @Body() body: { publicKey: string; allocatedIp: string; presharedKey?: string },
  ) {
    await this.wireguardService.addPeer(serverId, body.publicKey, body.allocatedIp, body.presharedKey);
    return { message: 'Peer added successfully' };
  }

  @Delete('servers/:serverId/peers/:publicKey')
  async removePeer(
    @Param('serverId') serverId: string,
    @Param('publicKey') publicKey: string,
  ) {
    await this.wireguardService.removePeer(serverId, publicKey);
    return { message: 'Peer removed successfully' };
  }
}

