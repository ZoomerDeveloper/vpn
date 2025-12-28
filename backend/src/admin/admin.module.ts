import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { UsersModule } from '../users/users.module';
import { PaymentsModule } from '../payments/payments.module';
import { VpnModule } from '../vpn/vpn.module';
import { WireguardModule } from '../wireguard/wireguard.module';

@Module({
  imports: [UsersModule, PaymentsModule, VpnModule, WireguardModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}

