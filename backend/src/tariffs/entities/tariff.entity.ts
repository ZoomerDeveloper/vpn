import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { Payment } from '../../payments/entities/payment.entity';

@Entity('tariffs')
export class Tariff {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  price: number;

  @Column({ default: 'RUB' })
  currency: string;

  @Column()
  durationDays: number;

  @Column({ default: 1 })
  devicesLimit: number;

  @Column({ default: true })
  isActive: boolean;

  @OneToMany(() => Payment, (payment) => payment.tariff)
  payments: Payment[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

