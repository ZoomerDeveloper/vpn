import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import { WireguardService } from './wireguard.service';
import { WireguardController } from './wireguard.controller';
import { HealthCheckService } from './health-check.service';
import { HealthCheckTask } from './health-check.task';
import { VpnServer } from './entities/vpn-server.entity';
import { ConfigModule } from '@nestjs/config';

@Module({
  imports: [
    TypeOrmModule.forFeature([VpnServer]),
    ConfigModule,
    ScheduleModule,
  ],
  controllers: [WireguardController],
  providers: [WireguardService, HealthCheckService, HealthCheckTask],
  exports: [WireguardService, HealthCheckService],
})
export class WireguardModule {}

