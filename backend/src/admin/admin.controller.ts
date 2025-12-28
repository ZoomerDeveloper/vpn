import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';
import { AdminService } from './admin.service';
import { UsersService } from '../users/users.service';
import { PaymentsService } from '../payments/payments.service';
import { VpnService } from '../vpn/vpn.service';
import { WireguardService } from '../wireguard/wireguard.service';

@Controller('admin')
export class AdminController {
  constructor(
    private adminService: AdminService,
    private usersService: UsersService,
    private paymentsService: PaymentsService,
    private vpnService: VpnService,
    private wireguardService: WireguardService,
  ) {}

  private checkAuth(req: Request): void {
    const token = req.headers.authorization?.replace('Bearer ', '') || req.query.token as string;
    if (!token || !this.adminService.validateToken(token)) {
      throw new UnauthorizedException('Invalid admin token');
    }
  }


  @Get('stats')
  async getStats(@Req() req: Request) {
    this.checkAuth(req);

    const users = await this.usersService.getAll();
    const payments = await this.paymentsService.getAll();
    const servers = await this.wireguardService.findAllServers();

    const activeUsers = users.filter(u => u.status === 'active' || u.status === 'trial').length;
    const totalRevenue = payments
      .filter(p => p.status === 'completed')
      .reduce((sum, p) => sum + Number(p.amount || 0), 0);

    return {
      totalUsers: users.length,
      activeUsers,
      totalPayments: payments.length,
      completedPayments: payments.filter(p => p.status === 'completed').length,
      pendingPayments: payments.filter(p => p.status === 'pending').length,
      totalRevenue,
      servers: servers.length,
    };
  }

  @Get('users')
  async getUsers(@Req() req: Request) {
    this.checkAuth(req);
    return this.usersService.getAll();
  }

  @Get('users/:id')
  async getUser(@Param('id') id: string, @Req() req: Request) {
    this.checkAuth(req);
    return this.usersService.findById(id);
  }

  @Post('users/:id/reset-trial')
  async resetTrial(@Param('id') id: string, @Req() req: Request) {
    this.checkAuth(req);
    await this.vpnService.deleteAllUserPeers(id);
    return this.usersService.resetTrial(id);
  }

  @Get('payments')
  async getPayments(@Req() req: Request) {
    this.checkAuth(req);
    return this.paymentsService.getAll();
  }

  @Get('payments/pending')
  async getPendingPayments(@Req() req: Request) {
    this.checkAuth(req);
    return this.paymentsService.getPendingPayments();
  }

  @Post('payments/:id/confirm')
  async confirmPayment(
    @Param('id') id: string,
    @Body() body: { transactionHash?: string },
    @Req() req: Request,
  ) {
    this.checkAuth(req);
    return this.paymentsService.confirmPayment(id, body.transactionHash);
  }

  @Patch('vpn/peers/:peerId/activate')
  async activatePeer(@Param('peerId') peerId: string, @Req() req: Request) {
    this.checkAuth(req);
    await this.vpnService.activatePeer(peerId);
    return { message: 'Peer activated' };
  }

  @Patch('vpn/peers/:peerId/deactivate')
  async deactivatePeer(@Param('peerId') peerId: string, @Req() req: Request) {
    this.checkAuth(req);
    await this.vpnService.deactivatePeer(peerId);
    return { message: 'Peer deactivated' };
  }

  @Get('servers')
  async getServers(@Req() req: Request) {
    this.checkAuth(req);
    return this.wireguardService.findAllServers();
  }
}

