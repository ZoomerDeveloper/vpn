import { Controller, Get, Post, Body, Param, Delete, Patch } from '@nestjs/common';
import { WireguardService } from './wireguard.service';
import { HealthCheckService } from './health-check.service';

@Controller('wireguard')
export class WireguardController {
  constructor(
    private readonly wireguardService: WireguardService,
    private readonly healthCheckService: HealthCheckService,
  ) {}

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

  @Patch('servers/:id')
  async updateServer(
    @Param('id') id: string,
    @Body() updateData: {
      name?: string;
      host?: string;
      port?: number;
      publicIp?: string;
      privateIp?: string;
      endpoint?: string;
      network?: string;
      dns?: string;
      isActive?: boolean;
      maxPeers?: number;
      priority?: number;
      region?: string;
    },
  ) {
    return this.wireguardService.updateServer(id, updateData);
  }

  @Delete('servers/:serverId/peers/:publicKey')
  async removePeer(
    @Param('serverId') serverId: string,
    @Param('publicKey') publicKey: string,
  ) {
    await this.wireguardService.removePeer(serverId, publicKey);
    return { message: 'Peer removed successfully' };
  }

  /**
   * Проверяет здоровье всех серверов
   */
  @Post('servers/health-check')
  async checkAllServers() {
    await this.healthCheckService.checkAllServers();
    return { message: 'Health check completed' };
  }

  /**
   * Проверяет здоровье одного сервера
   */
  @Post('servers/:id/health-check')
  async checkServerHealth(@Param('id') id: string) {
    await this.healthCheckService.checkSingleServer(id);
    const server = await this.wireguardService.findServerById(id);
    return {
      id: server.id,
      name: server.name,
      isHealthy: server.isHealthy,
      ping: server.ping,
      lastHealthCheck: server.lastHealthCheck,
    };
  }
}

