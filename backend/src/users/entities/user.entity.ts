import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { VpnPeer } from '../../vpn/entities/vpn-peer.entity';
import { Payment } from '../../payments/entities/payment.entity';

export enum UserStatus {
  ACTIVE = 'active',
  TRIAL = 'trial',
  EXPIRED = 'expired',
  BLOCKED = 'blocked',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  telegramId: string;

  @Column({ nullable: true })
  username: string;

  @Column({ nullable: true })
  firstName: string;

  @Column({ nullable: true })
  lastName: string;

  @Column({
    type: 'enum',
    enum: UserStatus,
    default: UserStatus.TRIAL,
  })
  status: UserStatus;

  @Column({ nullable: true })
  tariffId: string;

  @Column({ type: 'timestamp', nullable: true })
  expireAt: Date;

  @Column({ type: 'timestamp', nullable: true })
  trialStartedAt: Date;

  @Column({ type: 'timestamp', nullable: true })
  trialExpiresAt: Date;

  @Column({ default: false })
  trialUsed: boolean;

  @OneToMany(() => VpnPeer, (peer) => peer.user)
  peers: VpnPeer[];

  @OneToMany(() => Payment, (payment) => payment.user)
  payments: Payment[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

