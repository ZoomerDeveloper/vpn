import axios from 'axios';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Загружаем .env из корня проекта или текущей директории
dotenv.config({ path: path.join(__dirname, '../backend/.env') });
dotenv.config();

const API_URL = process.env.API_BASE_URL || process.env.BACKEND_URL || 'http://localhost:3000';

/**
 * Скрипт для проверки ожидающих платежей
 * Запускать через cron каждые 5-10 минут
 */
async function checkPendingPayments() {
  try {
    const response = await axios.get(`${API_URL}/payments/pending`);
    const payments = response.data;

    console.log(`Found ${payments.length} pending payments`);

    for (const payment of payments) {
      if (payment.provider === 'usdt_trc20' && payment.transactionHash) {
        try {
          // Проверяем транзакцию через API
          const checkResponse = await axios.post(
            `${API_URL}/payments/${payment.id}/confirm`,
            { transactionHash: payment.transactionHash },
          );

          if (checkResponse.data.status === 'completed') {
            console.log(`✓ Payment ${payment.id} confirmed`);
          }
        } catch (error: any) {
          console.error(`Error confirming payment ${payment.id}:`, error.message);
        }
      }
    }
  } catch (error: any) {
    console.error('Error checking payments:', error.message);
  }
}

checkPendingPayments();

