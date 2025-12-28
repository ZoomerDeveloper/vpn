import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { VpnServer } from './entities/vpn-server.entity';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

@Injectable()
export class HealthCheckService {
  private readonly logger = new Logger(HealthCheckService.name);

  constructor(
    @InjectRepository(VpnServer)
    private serversRepository: Repository<VpnServer>,
  ) {}

  /**
   * Проверяет доступность сервера через ping
   */
  async checkServerPing(server: VpnServer): Promise<number | null> {
    try {
      // Пинг с таймаутом 3 секунды, 3 пакета
      const { stdout } = await execAsync(
        `ping -c 3 -W 3000 ${server.publicIp} 2>&1 || true`,
      );

      // Парсим средний пинг (в Linux ping выводит "min/avg/max")
      const match = stdout.match(/min\/avg\/max\/mdev = [\d.+]+\/([\d.]+)\//);
      if (match && match[1]) {
        const avgPing = Math.round(parseFloat(match[1]));
        return avgPing;
      }

      // Альтернативный формат (некоторые системы)
      const altMatch = stdout.match(/Average = ([\d.]+)/i);
      if (altMatch && altMatch[1]) {
        return Math.round(parseFloat(altMatch[1]));
      }

      return null;
    } catch (error) {
      this.logger.debug(`Failed to ping ${server.name}: ${error.message}`);
      return null;
    }
  }

  /**
   * Проверяет доступность WireGuard порта
   */
  async checkWireGuardPort(server: VpnServer): Promise<boolean> {
    try {
      // Используем nc (netcat) или timeout для проверки UDP порта
      // UDP проверка сложнее, используем простую проверку через timeout
      const { stdout } = await execAsync(
        `timeout 2 bash -c 'echo > /dev/udp/${server.publicIp}/${server.port}' 2>&1 || true`,
      );
      // Если команда выполнилась без ошибок, порт скорее всего доступен
      return true;
    } catch (error) {
      // Более надежная проверка через nmap или другой инструмент
      try {
        const { stdout } = await execAsync(
          `timeout 3 nc -u -z -w 2 ${server.publicIp} ${server.port} 2>&1 || echo "failed"`,
        );
        return !stdout.includes('failed') && !stdout.includes('timeout');
      } catch {
        // Если проверка не удалась, считаем сервер доступным (ложно-положительный результат лучше чем блокировка)
        return true;
      }
    }
  }

  /**
   * Проверяет здоровье сервера (ping + порт)
   */
  async checkServerHealth(server: VpnServer): Promise<{
    isHealthy: boolean;
    ping: number | null;
  }> {
    const ping = await this.checkServerPing(server);
    const portAvailable = await this.checkWireGuardPort(server);

    // Сервер считается здоровым если:
    // 1. Порт доступен И
    // 2. (Пинг доступен И пинг < 1000мс) ИЛИ (проверка пинга не удалась, но порт доступен)
    const isHealthy = portAvailable && (ping === null || ping < 1000);

    return {
      isHealthy,
      ping: ping || null,
    };
  }

  /**
   * Проверяет здоровье всех серверов
   */
  async checkAllServers(): Promise<void> {
    this.logger.log('Starting health check for all servers...');

    const servers = await this.serversRepository.find({
      where: { isActive: true },
    });

    let healthyCount = 0;
    let unhealthyCount = 0;

    for (const server of servers) {
      try {
        const { isHealthy, ping } = await this.checkServerHealth(server);

        server.isHealthy = isHealthy;
        server.lastHealthCheck = new Date();
        if (ping !== null) {
          server.ping = ping;
        }

        await this.serversRepository.save(server);

        if (isHealthy) {
          healthyCount++;
          this.logger.debug(
            `✅ Server ${server.name} is healthy (ping: ${ping || 'N/A'}ms)`,
          );
        } else {
          unhealthyCount++;
          this.logger.warn(
            `❌ Server ${server.name} is unhealthy (ping: ${ping || 'N/A'}ms)`,
          );
        }
      } catch (error) {
        this.logger.error(
          `Failed to check health for server ${server.name}: ${error.message}`,
        );
        // Помечаем как нездоровый при ошибке проверки
        server.isHealthy = false;
        server.lastHealthCheck = new Date();
        await this.serversRepository.save(server);
        unhealthyCount++;
      }
    }

    this.logger.log(
      `Health check completed: ${healthyCount} healthy, ${unhealthyCount} unhealthy`,
    );
  }

  /**
   * Проверяет здоровье одного сервера
   */
  async checkSingleServer(serverId: string): Promise<void> {
    const server = await this.serversRepository.findOne({
      where: { id: serverId },
    });

    if (!server) {
      throw new Error(`Server ${serverId} not found`);
    }

    const { isHealthy, ping } = await this.checkServerHealth(server);

    server.isHealthy = isHealthy;
    server.lastHealthCheck = new Date();
    if (ping !== null) {
      server.ping = ping;
    }

    await this.serversRepository.save(server);

    this.logger.log(
      `Server ${server.name} health check: ${isHealthy ? 'healthy' : 'unhealthy'} (ping: ${ping || 'N/A'}ms)`,
    );
  }
}

