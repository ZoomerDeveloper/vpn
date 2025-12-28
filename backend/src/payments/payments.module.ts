import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { CurrencyService } from './currency.service';
import { Payment } from './entities/payment.entity';
import { UsersModule } from '../users/users.module';
import { TariffsModule } from '../tariffs/tariffs.module';
import { VpnModule } from '../vpn/vpn.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Payment]),
    UsersModule,
    TariffsModule,
    VpnModule,
  ],
  controllers: [PaymentsController],
  providers: [PaymentsService, CurrencyService],
  exports: [PaymentsService, CurrencyService],
})
export class PaymentsModule {}

