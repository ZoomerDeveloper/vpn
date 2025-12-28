import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { VpnPeer } from '../../vpn/entities/vpn-peer.entity';

@Entity('vpn_servers')
export class VpnServer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column()
  host: string;

  @Column({ type: 'int' })
  port: number;

  @Column({ type: 'inet' })
  publicIp: string;

  @Column({ type: 'inet' })
  privateIp: string;

  @Column({ type: 'inet' })
  endpoint: string;

  @Column({ type: 'inet' })
  network: string;

  @Column({ nullable: true })
  publicKey: string;

  @Column({ nullable: true })
  privateKey: string;

  @Column({ nullable: true })
  dns: string;

  @Column({ default: true })
  isActive: boolean;

  @Column({ default: 100 })
  maxPeers: number;

  @Column({ type: 'int', default: 0 })
  currentPeers: number;

  @Column({ type: 'int', nullable: true })
  ping: number; // Средний пинг в мс

  @Column({ type: 'timestamp', nullable: true })
  lastHealthCheck: Date;

  @Column({ default: true })
  isHealthy: boolean; // Доступен ли сервер

  @Column({ type: 'int', default: 100 })
  priority: number; // Приоритет (чем меньше, тем выше приоритет)

  @Column({ nullable: true })
  region: string; // Регион сервера (например, 'eu', 'us', 'asia', 'br', 'ru')

  @OneToMany(() => VpnPeer, (peer) => peer.server)
  peers: VpnPeer[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

