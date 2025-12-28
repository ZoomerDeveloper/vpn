import { DataSource } from 'typeorm';
import { config } from 'dotenv';
import { User } from '../users/entities/user.entity';
import { VpnPeer } from '../vpn/entities/vpn-peer.entity';
import { Payment } from '../payments/entities/payment.entity';
import { Tariff } from '../tariffs/entities/tariff.entity';
import { VpnServer } from '../wireguard/entities/vpn-server.entity';

config();

export default new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_DATABASE || 'vpn_service',
  entities: [User, VpnPeer, Payment, Tariff, VpnServer],
  migrations: ['src/database/migrations/*.ts'],
  synchronize: process.env.FORCE_SYNC === 'true', // Используйте FORCE_SYNC=true только для первого запуска
  logging: true,
});

