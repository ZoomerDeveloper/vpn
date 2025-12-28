import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { HealthCheckService } from './health-check.service';

@Injectable()
export class HealthCheckTask {
  private readonly logger = new Logger(HealthCheckTask.name);

  constructor(private healthCheckService: HealthCheckService) {}

  /**
   * Проверяет здоровье всех серверов каждые 5 минут
   */
  @Cron(CronExpression.EVERY_5_MINUTES)
  async handleHealthCheck() {
    this.logger.debug('Running scheduled health check...');
    try {
      await this.healthCheckService.checkAllServers();
    } catch (error) {
      this.logger.error(`Health check task failed: ${error.message}`, error.stack);
    }
  }
}

