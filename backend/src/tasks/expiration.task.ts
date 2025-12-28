import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { UsersService } from '../users/users.service';

@Injectable()
export class ExpirationTask {
  private readonly logger = new Logger(ExpirationTask.name);

  constructor(private usersService: UsersService) {}

  @Cron(CronExpression.EVERY_HOUR)
  async handleExpiration() {
    this.logger.log('Checking for expired users...');
    await this.usersService.checkExpiration();
  }
}

