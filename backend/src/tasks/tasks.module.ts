import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { ExpirationTask } from './expiration.task';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    UsersModule,
  ],
  providers: [ExpirationTask],
})
export class TasksModule {}

