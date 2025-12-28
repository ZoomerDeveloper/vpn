import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { VpnService } from './vpn.service';

@Injectable()
export class PeersRestoreTask implements OnModuleInit {
  private readonly logger = new Logger(PeersRestoreTask.name);

  constructor(private readonly vpnService: VpnService) {}

  async onModuleInit() {
    // Небольшая задержка чтобы WireGuard сервер успел запуститься
    setTimeout(async () => {
      try {
        await this.vpnService.restoreAllActivePeers();
      } catch (error) {
        this.logger.error(`Failed to restore peers: ${error.message}`);
      }
    }, 5000); // 5 секунд задержка
  }
}

