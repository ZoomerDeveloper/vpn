import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { VpnServer } from '../../wireguard/entities/vpn-server.entity';

@Entity('vpn_peers')
export class VpnPeer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @ManyToOne(() => User, (user) => user.peers)
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column()
  serverId: string;

  @ManyToOne(() => VpnServer)
  @JoinColumn({ name: 'serverId' })
  server: VpnServer;

  @Column({ unique: true })
  publicKey: string;

  @Column()
  privateKey: string;

  @Column({ nullable: true })
  presharedKey: string;

  @Column({ default: true })
  isActive: boolean;

  @Column({ type: 'inet', nullable: true })
  allocatedIp: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

