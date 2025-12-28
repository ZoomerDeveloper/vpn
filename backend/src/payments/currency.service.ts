import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';

export interface CurrencyRates {
  usdtToRub: number;
  rubToUsdt: number;
  usdtToUsd: number;
  lastUpdated: Date;
}

@Injectable()
export class CurrencyService {
  private readonly logger = new Logger(CurrencyService.name);
  private ratesCache: CurrencyRates | null = null;
  private cacheExpiry = 5 * 60 * 1000; // 5 минут

  /**
   * Получает курс USDT к рублям
   * Использует CoinGecko или Binance API для получения курса USDT к рублям
   */
  async getUsdtToRubRate(): Promise<number> {
    try {
      // Пробуем CoinGecko API (бесплатный, не требует API ключа)
      try {
        const coingeckoResponse = await axios.get(
          'https://api.coingecko.com/api/v3/simple/price?ids=tether&vs_currencies=rub',
          { timeout: 5000 }
        );
        const rate = coingeckoResponse.data?.tether?.rub;
        if (rate) {
          return rate;
        }
      } catch (error) {
        this.logger.warn(`CoinGecko API failed: ${error.message}`);
      }

      // Fallback: используем exchangerate-api для USD/RUB и предполагаем 1 USDT ≈ 1 USD
      try {
        const exchangeResponse = await axios.get(
          'https://api.exchangerate-api.com/v4/latest/USD',
          { timeout: 5000 }
        );
        const usdToRub = exchangeResponse.data?.rates?.RUB;
        if (usdToRub) {
          return usdToRub; // 1 USDT ≈ 1 USD
        }
      } catch (error) {
        this.logger.warn(`ExchangeRate API failed: ${error.message}`);
      }

      // Если все API недоступны, используем фиксированный курс
      this.logger.warn('All currency APIs failed, using default rate');
      return 92; // Примерно 92 рубля за USDT (примерный курс на 2024 год)
    } catch (error) {
      this.logger.error(`Failed to fetch USDT/RUB rate: ${error.message}`);
      return 92; // Fallback курс
    }
  }

  /**
   * Получает актуальные курсы валют с кэшированием
   */
  async getRates(): Promise<CurrencyRates> {
    const now = new Date();

    // Проверяем кэш
    if (
      this.ratesCache &&
      now.getTime() - this.ratesCache.lastUpdated.getTime() < this.cacheExpiry
    ) {
      return this.ratesCache;
    }

    // Получаем новые курсы
    const usdtToRub = await this.getUsdtToRubRate();
    const rubToUsdt = 1 / usdtToRub;
    const usdtToUsd = 1; // USDT привязан к USD (примерно)

    this.ratesCache = {
      usdtToRub,
      rubToUsdt,
      usdtToUsd,
      lastUpdated: now,
    };

    return this.ratesCache;
  }

  /**
   * Конвертирует рубли в USDT
   */
  async rubToUsdt(rubAmount: number): Promise<number> {
    const rates = await this.getRates();
    return rubAmount * rates.rubToUsdt;
  }

  /**
   * Конвертирует USDT в рубли
   */
  async usdtToRub(usdtAmount: number): Promise<number> {
    const rates = await this.getRates();
    return usdtAmount * rates.usdtToRub;
  }

  /**
   * Форматирует сумму для отображения
   */
  formatCurrency(amount: number, currency: string): string {
    if (currency === 'RUB') {
      return `${amount.toFixed(2)} ₽`;
    } else if (currency === 'USDT') {
      return `${amount.toFixed(2)} USDT`;
    } else if (currency === 'USD') {
      return `$${amount.toFixed(2)}`;
    }
    return `${amount.toFixed(2)} ${currency}`;
  }
}

