import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AdminService {
  constructor(private configService: ConfigService) {}

  validateToken(token: string): boolean {
    const adminToken = this.configService.get('ADMIN_TOKEN');
    return adminToken && token === adminToken;
  }
}

