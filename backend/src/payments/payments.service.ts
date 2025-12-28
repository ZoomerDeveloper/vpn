import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { Payment, PaymentStatus, PaymentProvider } from './entities/payment.entity';
import { UsersService } from '../users/users.service';
import { TariffsService } from '../tariffs/tariffs.service';
import { VpnService } from '../vpn/vpn.service';
import axios from 'axios';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);
  private readonly usdtAddress: string;
  private readonly tronApiUrl: string;
  private readonly tronApiKey: string;

  constructor(
    @InjectRepository(Payment)
    private paymentsRepository: Repository<Payment>,
    private usersService: UsersService,
    private tariffsService: TariffsService,
    private vpnService: VpnService,
    private configService: ConfigService,
  ) {
    this.usdtAddress = this.configService.get('USDT_TRC20_ADDRESS') || '';
    this.tronApiUrl = this.configService.get('TRON_NETWORK') || 'https://api.trongrid.io';
    this.tronApiKey = this.configService.get('TRON_API_KEY') || '';
  }

  /**
   * Создает новый платеж
   */
  async createPayment(
    userId: string,
    tariffId: string,
    provider: PaymentProvider = PaymentProvider.USDT_TRC20,
  ): Promise<Payment> {
    const user = await this.usersService.findById(userId);
    const tariff = await this.tariffsService.findById(tariffId);

    const payment = this.paymentsRepository.create({
      userId,
      tariffId,
      amount: tariff.price,
      currency: tariff.currency,
      status: PaymentStatus.PENDING,
      provider,
    });

    return this.paymentsRepository.save(payment);
  }

  /**
   * Генерирует адрес для оплаты USDT TRC20
   */
  async generatePaymentAddress(paymentId: string): Promise<{ address: string; amount: number }> {
    const payment = await this.paymentsRepository.findOne({ where: { id: paymentId } });

    if (!payment) {
      throw new Error('Payment not found');
    }

    if (payment.provider !== PaymentProvider.USDT_TRC20) {
      throw new Error('Payment provider is not USDT TRC20');
    }

    // В реальном сценарии здесь должна быть логика генерации уникального адреса
    // или использование sub-адресов. Для MVP используем основной адрес
    return {
      address: this.usdtAddress,
      amount: payment.amount,
    };
  }

  /**
   * Проверяет транзакцию USDT TRC20
   */
  async checkUsdtTransaction(transactionHash: string): Promise<boolean> {
    try {
      const headers: any = {};
      if (this.tronApiKey) {
        headers['TRON-PRO-API-KEY'] = this.tronApiKey;
      }

      const response = await axios.get(
        `${this.tronApiUrl}/v1/transactions/${transactionHash}`,
        { headers },
      );

      const transaction = response.data;
      
      // Проверяем, что транзакция успешна
      if (transaction.ret && transaction.ret[0]?.contractRet === 'SUCCESS') {
        // Проверяем, что это USDT TRC20 транзакция
        const contract = transaction.raw_data?.contract?.[0];
        if (contract?.type === 'TriggerSmartContract') {
          const parameter = contract.parameter?.value;
          if (parameter?.data?.startsWith('a9059cbb')) { // transfer method signature
            return true;
          }
        }
      }

      return false;
    } catch (error) {
      this.logger.error(`Failed to check USDT transaction: ${error.message}`);
      return false;
    }
  }

  /**
   * Подтверждает платеж и активирует подписку
   */
  async confirmPayment(paymentId: string, transactionHash?: string): Promise<Payment> {
    const payment = await this.paymentsRepository.findOne({
      where: { id: paymentId },
      relations: ['user', 'tariff'],
    });

    if (!payment) {
      throw new Error('Payment not found');
    }

    if (payment.status === PaymentStatus.COMPLETED) {
      return payment;
    }

    // Если есть transaction hash, проверяем его
    if (transactionHash && payment.provider === PaymentProvider.USDT_TRC20) {
      const isValid = await this.checkUsdtTransaction(transactionHash);
      if (!isValid) {
        throw new Error('Invalid transaction');
      }
      payment.transactionHash = transactionHash;
    }

    payment.status = PaymentStatus.COMPLETED;
    await this.paymentsRepository.save(payment);

    // Активируем подписку пользователя
    const expireAt = new Date();
    expireAt.setDate(expireAt.getDate() + payment.tariff.durationDays);

    await this.usersService.activateSubscription(
      payment.userId,
      payment.tariffId,
      expireAt,
    );

    this.logger.log(`Payment ${paymentId} confirmed, subscription activated for user ${payment.userId}`);

    return payment;
  }

  /**
   * Обновляет статус платежа
   */
  async updatePaymentStatus(
    paymentId: string,
    status: PaymentStatus,
    metadata?: any,
  ): Promise<Payment> {
    const payment = await this.paymentsRepository.findOne({ where: { id: paymentId } });

    if (!payment) {
      throw new Error('Payment not found');
    }

    payment.status = status;
    if (metadata) {
      payment.metadata = JSON.stringify(metadata);
    }

    return this.paymentsRepository.save(payment);
  }

  /**
   * Получает платеж по ID
   */
  async findById(paymentId: string): Promise<Payment> {
    const payment = await this.paymentsRepository.findOne({
      where: { id: paymentId },
      relations: ['user', 'tariff'],
    });

    if (!payment) {
      throw new Error('Payment not found');
    }

    return payment;
  }

  /**
   * Получает платежи пользователя
   */
  async getUserPayments(userId: string): Promise<Payment[]> {
    return this.paymentsRepository.find({
      where: { userId },
      relations: ['tariff'],
      order: { createdAt: 'DESC' },
    });
  }

  /**
   * Получает ожидающие платежи для проверки
   */
  async getPendingPayments(): Promise<Payment[]> {
    return this.paymentsRepository.find({
      where: { status: PaymentStatus.PENDING },
      relations: ['user', 'tariff'],
    });
  }
}

