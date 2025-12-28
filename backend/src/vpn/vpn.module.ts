import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { VpnController } from './vpn.controller';
import { VpnService } from './vpn.service';
import { VpnPeer } from './entities/vpn-peer.entity';
import { UsersModule } from '../users/users.module';
import { WireguardModule } from '../wireguard/wireguard.module';
import { TariffsModule } from '../tariffs/tariffs.module';
import { PeersRestoreTask } from './peers-restore.task';

@Module({
  imports: [
    TypeOrmModule.forFeature([VpnPeer]),
    forwardRef(() => UsersModule),
    WireguardModule,
    TariffsModule,
  ],
  controllers: [VpnController],
  providers: [VpnService, PeersRestoreTask],
  exports: [VpnService],
})
export class VpnModule {}

