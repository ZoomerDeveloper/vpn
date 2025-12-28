import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DatabaseModule } from './database/database.module';
import { UsersModule } from './users/users.module';
import { VpnModule } from './vpn/vpn.module';
import { PaymentsModule } from './payments/payments.module';
import { TariffsModule } from './tariffs/tariffs.module';
import { WireguardModule } from './wireguard/wireguard.module';
import { TasksModule } from './tasks/tasks.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    DatabaseModule,
    UsersModule,
    VpnModule,
    PaymentsModule,
    TariffsModule,
    WireguardModule,
    TasksModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}

