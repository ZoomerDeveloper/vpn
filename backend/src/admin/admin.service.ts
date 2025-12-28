import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(private configService: ConfigService) {}

  validateToken(token: string): boolean {
    const adminToken = this.configService.get('ADMIN_TOKEN');
    return adminToken && token === adminToken;
  }

  /**
   * Получает статус WireGuard peer'ов (handshake, трафик и т.д.)
   */
  async getWireguardStatus(): Promise<Record<string, any>> {
    try {
      const interfaceName = this.configService.get('WG_INTERFACE') || 'wg0';
      const { stdout } = await execAsync(`wg show ${interfaceName}`);
      
      const peers: Record<string, any> = {};
      let currentPeer: string | null = null;

      for (const line of stdout.split('\n')) {
        if (line.startsWith('peer:')) {
          const publicKey = line.replace('peer:', '').trim();
          currentPeer = publicKey;
          peers[publicKey] = {
            publicKey,
            endpoint: null,
            allowedIps: null,
            latestHandshake: null,
            transfer: null,
          };
        } else if (currentPeer) {
          if (line.includes('endpoint:')) {
            peers[currentPeer].endpoint = line.replace('endpoint:', '').trim();
          } else if (line.includes('allowed ips:')) {
            peers[currentPeer].allowedIps = line.replace('allowed ips:', '').trim();
          } else if (line.includes('latest handshake:')) {
            peers[currentPeer].latestHandshake = line.replace('latest handshake:', '').trim();
          } else if (line.includes('transfer:')) {
            peers[currentPeer].transfer = line.replace('transfer:', '').trim();
          }
        }
      }

      return peers;
    } catch (error: any) {
      this.logger.error(`Failed to get WireGuard status: ${error.message}`);
      return {};
    }
  }

  /**
   * Получает статус подключения для конкретного peer'а
   */
  async getPeerStatus(publicKey: string): Promise<{
    connected: boolean;
    latestHandshake: string | null;
    endpoint: string | null;
    transfer: string | null;
  }> {
    const allPeers = await this.getWireguardStatus();
    const peer = allPeers[publicKey];

    if (!peer) {
      return {
        connected: false,
        latestHandshake: null,
        endpoint: null,
        transfer: null,
      };
    }

    // Peer считается подключенным если есть handshake не старше 3 минут
    let connected = false;
    if (peer.latestHandshake) {
      const handshake = peer.latestHandshake.toLowerCase();
      // Если есть handshake и он не содержит день/неделю/месяц
      if (!handshake.includes('day') && 
          !handshake.includes('week') && 
          !handshake.includes('month') &&
          !handshake.includes('hour')) {
        // Проверяем минуты (берем первое число из строки)
        const minutesMatch = handshake.match(/(\d+)\s*minute/);
        if (!minutesMatch) {
          // Нет упоминания минут - значит секунды, значит подключен
          connected = true;
        } else {
          const minutes = parseInt(minutesMatch[1]);
          connected = minutes < 3; // Менее 3 минут считаем подключенным
        }
      }
    }

    return {
      connected,
      latestHandshake: peer.latestHandshake,
      endpoint: peer.endpoint,
      transfer: peer.transfer,
    };
  }
}

