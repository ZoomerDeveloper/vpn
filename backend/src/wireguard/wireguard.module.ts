import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WireguardService } from './wireguard.service';
import { WireguardController } from './wireguard.controller';
import { VpnServer } from './entities/vpn-server.entity';
import { ConfigModule } from '@nestjs/config';

@Module({
  imports: [
    TypeOrmModule.forFeature([VpnServer]),
    ConfigModule,
  ],
  controllers: [WireguardController],
  providers: [WireguardService],
  exports: [WireguardService],
})
export class WireguardModule {}

