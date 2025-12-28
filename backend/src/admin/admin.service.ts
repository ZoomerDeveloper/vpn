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
      
      // Пробуем выполнить wg show (с sudo если доступно, без sudo если работает)
      let stdout: string;
      try {
        // Сначала пробуем с sudo (обычно нужен для wg show)
        const result = await execAsync(`sudo wg show ${interfaceName} 2>&1`);
        stdout = result.stdout;
        // Если в выводе есть ошибка sudo (требует пароль), пробуем без sudo
        if (stdout.includes('password') || stdout.includes('sudo:')) {
          throw new Error('Sudo requires password');
        }
      } catch (error: any) {
        // Если sudo не работает, пробуем без sudo
        this.logger.debug(`Trying wg show without sudo: ${error.message}`);
        try {
          const result = await execAsync(`wg show ${interfaceName} 2>&1`);
          stdout = result.stdout;
        } catch (err: any) {
          this.logger.error(`Failed to execute wg show: ${err.message}`);
          throw err;
        }
      }
      
      if (!stdout || stdout.trim() === '') {
        this.logger.warn('WireGuard status output is empty');
        return {};
      }
      
      this.logger.debug(`WireGuard status output (first 500 chars):\n${stdout.substring(0, 500)}`);
      
      const peers: Record<string, any> = {};
      let currentPeer: string | null = null;
      let transferLines: string[] = [];

      for (const line of stdout.split('\n')) {
        const trimmedLine = line.trim();
        
        if (!trimmedLine) continue;
        
        if (trimmedLine.startsWith('peer:')) {
          // Сохраняем предыдущий peer если был
          if (currentPeer && transferLines.length > 0) {
            peers[currentPeer].transfer = transferLines.join(', ');
            transferLines = [];
          }
          
          const publicKey = trimmedLine.replace(/^peer:\s*/, '').trim();
          if (publicKey) {
            currentPeer = publicKey;
            peers[publicKey] = {
              publicKey,
              endpoint: null,
              allowedIps: null,
              latestHandshake: null,
              transfer: null,
            };
            this.logger.debug(`Found peer: ${publicKey.substring(0, 16)}...`);
          }
        } else if (currentPeer) {
          if (trimmedLine.startsWith('endpoint:')) {
            peers[currentPeer].endpoint = trimmedLine.replace(/^endpoint:\s*/, '').trim();
          } else if (trimmedLine.startsWith('allowed ips:')) {
            peers[currentPeer].allowedIps = trimmedLine.replace(/^allowed ips:\s*/, '').trim();
          } else if (trimmedLine.startsWith('latest handshake:')) {
            const handshake = trimmedLine.replace(/^latest handshake:\s*/, '').trim();
            peers[currentPeer].latestHandshake = handshake;
            this.logger.debug(`Peer ${currentPeer.substring(0, 16)}... handshake: ${handshake}`);
          } else if (trimmedLine.match(/^\d+\s+(B|KB|MB|GB)/)) {
            // Строка с трафиком (может быть несколько строк для received/sent)
            transferLines.push(trimmedLine);
          }
        }
      }
      
      // Сохраняем transfer для последнего peer
      if (currentPeer && transferLines.length > 0) {
        peers[currentPeer].transfer = transferLines.join(', ');
      }

      this.logger.log(`Parsed ${Object.keys(peers).length} peers from WireGuard status`);
      return peers;
    } catch (error: any) {
      this.logger.error(`Failed to get WireGuard status: ${error.message}`, error.stack);
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

