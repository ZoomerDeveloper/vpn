import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { VpnServer } from '../wireguard/entities/vpn-server.entity';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(
    private configService: ConfigService,
    @InjectRepository(VpnServer)
    private serversRepository: Repository<VpnServer>,
  ) {}

  validateToken(token: string): boolean {
    const adminToken = this.configService.get('ADMIN_TOKEN');
    return adminToken && token === adminToken;
  }

  /**
   * Получает статус WireGuard peer'ов (handshake, трафик и т.д.)
   * Поддерживает проверку на локальном сервере и на удаленных серверах
   */
  async getWireguardStatus(serverId?: string, serverHost?: string): Promise<Record<string, any>> {
    try {
      const interfaceName = this.configService.get('WG_INTERFACE') || 'wg0';
      
      let stdout: string;
      
      // Если указан serverHost, это удаленный сервер - используем SSH
      if (serverHost && serverHost !== 'localhost' && !serverHost.startsWith('127.')) {
        this.logger.debug(`Checking remote server: ${serverHost}`);
        try {
          // Используем SSH для выполнения команды на удаленном сервере
          // Предполагаем что SSH настроен без пароля (ключи)
          // Добавляем логирование для отладки
          const sshCommand = `ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes root@${serverHost} "wg show ${interfaceName} 2>&1"`;
          this.logger.debug(`Executing SSH command: ssh root@${serverHost}`);
          const result = await execAsync(sshCommand);
          stdout = result.stdout;
          this.logger.debug(`SSH command succeeded, output length: ${stdout.length}`);
        } catch (error: any) {
          this.logger.warn(`Failed to check remote server ${serverHost}: ${error.message}`);
          // Возвращаем пустой результат если не удалось подключиться
          return {};
        }
      } else {
        // Локальный сервер - выполняем команду напрямую
        try {
          const result = await execAsync(`wg show ${interfaceName} 2>&1`);
          stdout = result.stdout;
        } catch (error: any) {
          // Если без sudo не работает, пробуем с sudo (для обычных пользователей)
          this.logger.debug(`Trying wg show with sudo: ${error.message}`);
          try {
            const result = await execAsync(`sudo wg show ${interfaceName} 2>&1`);
            stdout = result.stdout;
            // Проверяем что это не ошибка sudo
            if (stdout.includes('password') || stdout.includes('sudo:')) {
              throw new Error('Sudo requires password');
            }
          } catch (err: any) {
            this.logger.error(`Failed to execute wg show: ${err.message}`);
            throw err;
          }
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
    if (peer.latestHandshake && peer.latestHandshake.trim() !== '') {
      const handshake = peer.latestHandshake.toLowerCase().trim();
      
      // Проверяем что handshake не слишком старый (не дни/недели/месяцы/часы)
      if (!handshake.includes('day') && 
          !handshake.includes('week') && 
          !handshake.includes('month') &&
          !handshake.includes('hour')) {
        
        // Ищем минуты в формате "X minute(s)" или "X minute, Y seconds"
        const minutesMatch = handshake.match(/(\d+)\s*minute/);
        if (!minutesMatch) {
          // Нет упоминания минут - значит только секунды (например "37 seconds ago"), точно подключен
          connected = true;
        } else {
          const minutes = parseInt(minutesMatch[1], 10);
          // Менее 3 минут считаем подключенным
          connected = minutes < 3;
        }
      }
      // Если старше часа - connected останется false
    }

    return {
      connected,
      latestHandshake: peer.latestHandshake,
      endpoint: peer.endpoint,
      transfer: peer.transfer,
    };
  }
}

