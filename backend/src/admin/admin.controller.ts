import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  Req,
  Res,
  UnauthorizedException,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { AdminService } from './admin.service';
import { UsersService } from '../users/users.service';
import { PaymentsService } from '../payments/payments.service';
import { VpnService } from '../vpn/vpn.service';
import { WireguardService } from '../wireguard/wireguard.service';
import * as path from 'path';
import * as fs from 'fs';

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

  @Get()
  adminPage(@Res() res: Response, @Req() req: Request) {
    const token = req.query.token as string;
    if (!token || !this.adminService.validateToken(token)) {
      return res.status(401).send('Unauthorized. Please provide valid token in query parameter.');
    }

    // Путь к HTML файлу - пробуем несколько вариантов
    const possiblePaths = [
      path.join(process.cwd(), 'admin', 'index.html'), // В корне проекта
      path.join(__dirname, '..', '..', 'admin', 'index.html'), // От dist/admin
      path.join(__dirname, '..', 'admin', 'index.html'), // От dist/admin (если скопировано)
    ];
    
    let adminHtmlPath: string | null = null;
    for (const p of possiblePaths) {
      if (fs.existsSync(p)) {
        adminHtmlPath = p;
        break;
      }
    }
    
    if (adminHtmlPath) {
      return res.sendFile(path.resolve(adminHtmlPath));
    }
    
    // Если файл не найден, возвращаем простую HTML страницу с встроенным интерфейсом
    return res.send(`<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPN Admin Panel</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; color: #333; }
        .header { background: #2563eb; color: white; padding: 1rem 2rem; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .container { max-width: 1400px; margin: 0 auto; padding: 2rem; }
        .error { background: #fee2e2; color: #991b1b; padding: 1rem; border-radius: 6px; margin-bottom: 1rem; }
        .info { background: #dbeafe; color: #1e40af; padding: 1rem; border-radius: 6px; margin-bottom: 1rem; }
        .endpoints { background: white; padding: 1.5rem; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .endpoints ul { list-style: none; margin-top: 1rem; }
        .endpoints li { padding: 0.5rem 0; border-bottom: 1px solid #e5e5e5; }
        .endpoints code { background: #f3f4f6; padding: 0.25rem 0.5rem; border-radius: 4px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="header"><h1>🔐 VPN Admin Panel</h1></div>
    <div class="container">
        <div class="error">
            <strong>Внимание:</strong> HTML файл админки не найден. Используйте API endpoints напрямую или проверьте путь к файлу.
        </div>
        <div class="info">
            Проверьте что файл <code>backend/admin/index.html</code> существует и скопирован при билде в <code>backend/dist/admin/index.html</code>
        </div>
        <div class="endpoints">
            <h2>API Endpoints:</h2>
            <ul>
                <li><code>GET /admin/stats?token=${token}</code> - Статистика</li>
                <li><code>GET /admin/users?token=${token}</code> - Список пользователей</li>
                <li><code>GET /admin/payments?token=${token}</code> - Список платежей</li>
                <li><code>GET /admin/servers?token=${token}</code> - Список серверов</li>
                <li><code>POST /admin/users/:id/reset-trial?token=${token}</code> - Сбросить trial</li>
                <li><code>PATCH /admin/vpn/peers/:peerId/activate?token=${token}</code> - Активировать peer</li>
                <li><code>PATCH /admin/vpn/peers/:peerId/deactivate?token=${token}</code> - Деактивировать peer</li>
                <li><code>POST /admin/payments/:id/confirm?token=${token}</code> - Подтвердить платеж</li>
            </ul>
        </div>
    </div>
</body>
</html>`);
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

  @Get('wireguard/status')
  async getWireguardStatus(@Req() req: Request) {
    this.checkAuth(req);
    return this.adminService.getWireguardStatus();
  }

  @Get('users')
  async getUsers(@Req() req: Request) {
    this.checkAuth(req);
    const users = await this.usersService.getAll();
    
    // Получаем статус всех peer'ов один раз
    const wgStatus = await this.adminService.getWireguardStatus();

    // Добавляем статус подключения к каждому пользователю
    const usersWithStatus = users.map((user) => {
      const peers = user.peers || [];
      const peersWithStatus = peers.map((peer) => {
        if (peer.isActive && peer.publicKey) {
          const peerData = wgStatus[peer.publicKey];
          if (peerData) {
            // Определяем подключен ли peer
            // Peer считается подключенным если есть handshake не старше 3 минут
            let connected = false;
            if (peerData.latestHandshake && peerData.latestHandshake.trim() !== '') {
              const handshake = peerData.latestHandshake.toLowerCase().trim();
              
              // Проверяем что handshake не слишком старый
              if (!handshake.includes('day') && 
                  !handshake.includes('week') && 
                  !handshake.includes('month') &&
                  !handshake.includes('hour')) {
                // Ищем минуты в формате "X minute(s)" или "X minute, Y seconds"
                const minutesMatch = handshake.match(/(\d+)\s*minute/);
                if (!minutesMatch) {
                  // Нет упоминания минут - значит только секунды, точно подключен
                  connected = true;
                } else {
                  const minutes = parseInt(minutesMatch[1], 10);
                  // Менее 3 минут считаем подключенным
                  connected = minutes < 3;
                }
              }
              // Если старше часа - connected останется false
            } else {
              // Нет handshake вообще - не подключен
              connected = false;
            }
            
            return {
              ...peer,
              connectionStatus: {
                connected,
                latestHandshake: peerData.latestHandshake,
                endpoint: peerData.endpoint,
                transfer: peerData.transfer,
              },
            };
          }
        }
        return {
          ...peer,
          connectionStatus: {
            connected: false,
            latestHandshake: null,
            endpoint: null,
            transfer: null,
          },
        };
      });

      return {
        ...user,
        peers: peersWithStatus,
      };
    });

    return usersWithStatus;
  }
}
