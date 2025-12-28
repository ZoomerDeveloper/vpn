import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { VpnServer } from './entities/vpn-server.entity';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

@Injectable()
export class WireguardService {
  private readonly logger = new Logger(WireguardService.name);
  private readonly useLocal: boolean;

  constructor(
    @InjectRepository(VpnServer)
    private serversRepository: Repository<VpnServer>,
    private configService: ConfigService,
  ) {
    // Если WG_SERVERS содержит localhost или 127.0.0.1, используем локальные команды
    this.useLocal = process.env.WG_USE_LOCAL === 'true';
  }

  /**
   * Выполняет команду на сервере (локально или через SSH)
   */
  private async executeCommand(command: string, server?: VpnServer): Promise<string> {
    try {
      if (this.useLocal || !server) {
        // Локальное выполнение
        const result = await execAsync(command);
        return result.stdout.trim();
      } else {
        // Выполнение через SSH
        // Для MVP предполагаем, что команды выполняются локально
        // В продакшене здесь должна быть SSH интеграция
        const sshCommand = server.host === 'localhost' || server.host === '127.0.0.1'
          ? command
          : `ssh root@${server.host} "${command}"`;
        
        const result = await execAsync(sshCommand);
        return result.stdout.trim();
      }
    } catch (error: any) {
      this.logger.error(`Command failed: ${command}`, error);
      throw error;
    }
  }

  /**
   * Генерирует пару ключей WireGuard
   */
  async generateKeyPair(): Promise<{ privateKey: string; publicKey: string }> {
    try {
      // Генерируем приватный ключ
      const privateKeyResult = await this.executeCommand('wg genkey');
      const privateKey = privateKeyResult.trim();

      // Генерируем публичный ключ из приватного
      const publicKeyResult = await this.executeCommand(
        `echo "${privateKey}" | wg pubkey`,
      );
      const publicKey = publicKeyResult.trim();

      return { privateKey, publicKey };
    } catch (error) {
      this.logger.error('Failed to generate WireGuard keys', error);
      throw new Error('Failed to generate WireGuard keys');
    }
  }

  /**
   * Генерирует preshared key
   */
  async generatePresharedKey(): Promise<string> {
    try {
      const result = await this.executeCommand('wg genpsk');
      return result.trim();
    } catch (error) {
      this.logger.error('Failed to generate preshared key', error);
      throw new Error('Failed to generate preshared key');
    }
  }

  /**
   * Генерирует конфиг для клиента
   */
  async generateConfig(
    server: VpnServer,
    privateKey: string,
    publicKey: string,
    presharedKey?: string,
    allocatedIp?: string,
  ): Promise<string> {
    const allowedIPs = this.configService.get('WG_ALLOWED_IPS') || '0.0.0.0/0,::/0';
    const dns = server.dns || this.configService.get('WG_DNS') || '1.1.1.1,8.8.8.8';

    let config = `[Interface]\n`;
    config += `PrivateKey = ${privateKey}\n`;
    if (allocatedIp) {
      config += `Address = ${allocatedIp}\n`;
    }
    config += `DNS = ${dns}\n\n`;
    config += `[Peer]\n`;
    config += `PublicKey = ${server.publicKey}\n`;
    config += `Endpoint = ${server.endpoint}:${server.port}\n`;
    config += `AllowedIPs = ${allowedIPs}\n`;
    if (presharedKey) {
      config += `PresharedKey = ${presharedKey}\n`;
    }
    config += `PersistentKeepalive = 25\n`;

    return config;
  }

  /**
   * Добавляет peer на сервер WireGuard
   */
  async addPeer(
    serverId: string,
    publicKey: string,
    allocatedIp: string,
    presharedKey?: string,
  ): Promise<void> {
    const server = await this.serversRepository.findOne({
      where: { id: serverId },
    });

    if (!server) {
      throw new Error(`Server ${serverId} not found`);
    }

    const interfaceName = this.configService.get('WG_INTERFACE') || 'wg0';
    
    try {
      // Формируем команду для добавления peer
      let command = `wg set ${interfaceName} peer ${publicKey} allowed-ips ${allocatedIp}`;
      
      if (presharedKey) {
        // Сохраняем preshared key во временный файл
        const pskFile = `/tmp/preshared_${Date.now()}_${Math.random().toString(36).substring(7)}.key`;
        await this.executeCommand(`echo "${presharedKey}" > ${pskFile}`);
        command = `wg set ${interfaceName} peer ${publicKey} allowed-ips ${allocatedIp} preshared-key ${pskFile}`;
        
        // Выполняем команду
        await this.executeCommand(command, server);
        
        // Удаляем временный файл
        await this.executeCommand(`rm -f ${pskFile}`, server).catch(() => {
          // Игнорируем ошибки удаления
        });
      } else {
        await this.executeCommand(command, server);
      }

      // Обновляем счетчик peers
      server.currentPeers += 1;
      await this.serversRepository.save(server);

      this.logger.log(`Peer ${publicKey.substring(0, 16)}... added to server ${server.name}`);
    } catch (error: any) {
      this.logger.error(`Failed to add peer to server ${serverId}`, error);
      throw new Error(`Failed to add peer: ${error.message}`);
    }
  }

  /**
   * Удаляет peer с сервера WireGuard
   */
  async removePeer(serverId: string, publicKey: string): Promise<void> {
    const server = await this.serversRepository.findOne({
      where: { id: serverId },
    });

    if (!server) {
      throw new Error(`Server ${serverId} not found`);
    }

    const interfaceName = this.configService.get('WG_INTERFACE') || 'wg0';

    try {
      await this.executeCommand(
        `wg set ${interfaceName} peer ${publicKey} remove`,
        server,
      );

      // Обновляем счетчик peers
      if (server.currentPeers > 0) {
        server.currentPeers -= 1;
        await this.serversRepository.save(server);
      }

      this.logger.log(`Peer ${publicKey.substring(0, 16)}... removed from server ${server.name}`);
    } catch (error: any) {
      this.logger.error(`Failed to remove peer from server ${serverId}`, error);
      throw new Error(`Failed to remove peer: ${error.message}`);
    }
  }

  /**
   * Выделяет IP адрес для peer
   */
  allocateIp(server: VpnServer): string {
    const network = server.network || '10.0.0.0/24';
    const [baseIp, mask] = network.split('/');
    const baseParts = baseIp.split('.').map(Number);
    
    // Простая логика: используем последний октет от 2 до 254
    const lastOctet = (server.currentPeers % 253) + 2;
    
    return `${baseParts[0]}.${baseParts[1]}.${baseParts[2]}.${lastOctet}/32`;
  }

  /**
   * Получает доступный сервер
   */
  async getAvailableServer(): Promise<VpnServer> {
    const servers = await this.serversRepository.find({
      where: { isActive: true },
      order: { currentPeers: 'ASC' },
    });

    if (servers.length === 0) {
      throw new Error('No active servers available');
    }

    // Выбираем сервер с наименьшим количеством peers
    return servers[0];
  }

  async findAllServers(): Promise<VpnServer[]> {
    return this.serversRepository.find();
  }

  async findServerById(id: string): Promise<VpnServer> {
    const server = await this.serversRepository.findOne({ where: { id } });
    if (!server) {
      throw new Error(`Server ${id} not found`);
    }
    return server;
  }

  async createServer(serverData: {
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
  }): Promise<VpnServer> {
    let publicKey = serverData.publicKey;
    let privateKey = serverData.privateKey;

    if (!publicKey || !privateKey) {
      const keys = await this.generateKeyPair();
      publicKey = keys.publicKey;
      privateKey = keys.privateKey;
    }

    const server = this.serversRepository.create({
      ...serverData,
      publicKey,
      privateKey,
    });

    return this.serversRepository.save(server);
  }
}
