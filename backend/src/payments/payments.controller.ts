import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Patch,
} from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { PaymentProvider } from './entities/payment.entity';

@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post()
  async createPayment(@Body() body: {
    userId: string;
    tariffId: string;
    provider?: PaymentProvider;
  }) {
    return this.paymentsService.createPayment(
      body.userId,
      body.tariffId,
      body.provider,
    );
  }

  @Get(':id')
  async getPayment(@Param('id') id: string) {
    return this.paymentsService.findById(id);
  }

  @Get('user/:userId')
  async getUserPayments(@Param('userId') userId: string) {
    return this.paymentsService.getUserPayments(userId);
  }

  @Get('pending')
  async getPendingPayments() {
    return this.paymentsService.getPendingPayments();
  }

  @Post(':id/address')
  async generatePaymentAddress(@Param('id') id: string) {
    return this.paymentsService.generatePaymentAddress(id);
  }

  @Post(':id/confirm')
  async confirmPayment(
    @Param('id') id: string,
    @Body() body: { transactionHash?: string },
  ) {
    return this.paymentsService.confirmPayment(id, body.transactionHash);
  }

  @Patch(':id/status')
  async updateStatus(
    @Param('id') id: string,
    @Body() body: { status: string; metadata?: any },
  ) {
    return this.paymentsService.updatePaymentStatus(id, body.status as any, body.metadata);
  }
}
