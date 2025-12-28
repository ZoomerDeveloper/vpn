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
import { Tariff } from '../../tariffs/entities/tariff.entity';

export enum PaymentStatus {
  PENDING = 'pending',
  COMPLETED = 'completed',
  FAILED = 'failed',
  CANCELLED = 'cancelled',
}

export enum PaymentProvider {
  USDT_TRC20 = 'usdt_trc20',
  YOOKASSA = 'yookassa',
  TELEGRAM = 'telegram',
}

@Entity('payments')
export class Payment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @ManyToOne(() => User, (user) => user.payments)
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ nullable: true })
  tariffId: string;

  @ManyToOne(() => Tariff)
  @JoinColumn({ name: 'tariffId' })
  tariff: Tariff;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  amount: number;

  @Column({ default: 'RUB' })
  currency: string;

  @Column({
    type: 'enum',
    enum: PaymentStatus,
    default: PaymentStatus.PENDING,
  })
  status: PaymentStatus;

  @Column({
    type: 'enum',
    enum: PaymentProvider,
    default: PaymentProvider.USDT_TRC20,
  })
  provider: PaymentProvider;

  @Column({ nullable: true, unique: true })
  transactionHash: string;

  @Column({ nullable: true })
  externalId: string;

  @Column({ type: 'text', nullable: true })
  metadata: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

