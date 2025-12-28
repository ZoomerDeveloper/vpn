import { Telegraf, Context } from 'telegraf';
import { config } from 'dotenv';
import { startHandler } from './handlers/start.handler';
import { trialHandler } from './handlers/trial.handler';
import { buyHandler, tariffCallbackHandler } from './handlers/buy.handler';
import { statusHandler } from './handlers/status.handler';
import { supportHandler } from './handlers/support.handler';
import { myDevicesHandler, deviceCallbackHandler } from './handlers/devices.handler';
import { BotService } from './services/bot.service';

config();

const bot = new Telegraf(process.env.TELEGRAM_BOT_TOKEN || '');

// Инициализируем сервис
const botService = new BotService(process.env.API_BASE_URL || 'http://localhost:3000');

// Команды
bot.command('start', (ctx) => startHandler(ctx, botService));
bot.command('trial', (ctx) => trialHandler(ctx, botService));
bot.command('buy', (ctx) => buyHandler(ctx, botService));
bot.command('status', (ctx) => statusHandler(ctx, botService));
bot.command('support', (ctx) => supportHandler(ctx));
bot.command('devices', (ctx) => myDevicesHandler(ctx, botService));

// Callbacks
bot.action(/^tariff:(.+)$/, (ctx) => tariffCallbackHandler(ctx, botService));
bot.action(/^peer_info:(.+)$/, (ctx) => deviceCallbackHandler(ctx, botService));
bot.action(/^peer_delete:(.+)$/, async (ctx) => {
  try {
    const peerId = ctx.match[1];
    const telegramId = ctx.from.id.toString();
    
    const user = await botService.getUserByTelegramId(telegramId);
    if (!user) {
      return ctx.answerCbQuery('Пользователь не найден');
    }

    await botService.deactivatePeer(peerId, user.id);
    await ctx.answerCbQuery('Устройство удалено');
    await ctx.deleteMessage();
    await ctx.reply('Устройство успешно удалено.');
  } catch (error: any) {
    await ctx.answerCbQuery('Ошибка при удалении устройства');
    console.error('Error deleting peer:', error);
  }
});

// Обработка текстовых сообщений (для хеша транзакции)
bot.on('text', async (ctx) => {
  // Простая проверка на хеш транзакции (64 символа hex)
  const text = ctx.message.text;
  if (text && /^[a-fA-F0-9]{64}$/.test(text)) {
    try {
      const telegramId = ctx.from.id.toString();
      const user = await botService.getUserByTelegramId(telegramId);
      
      if (!user) {
        await ctx.reply('Сначала выполните команду /start');
        return;
      }

      // Здесь должна быть логика получения paymentId из контекста/БД
      // Для MVP упрощаем: ищем последний pending payment пользователя
      await ctx.reply('⏳ Проверяю транзакцию...');

      // В реальном приложении нужно получать paymentId из состояния
      // Для примера, можно использовать простой in-memory store или БД
      const message = `
✅ *Транзакция получена!*

Проверяю платеж. Это может занять несколько минут.

После подтверждения вы получите конфигурацию VPN автоматически.

/status - Проверить статус
      `;

      await ctx.reply(message, { parse_mode: 'Markdown' });

      // TODO: Здесь должна быть логика подтверждения платежа через API
      // await botService.confirmPayment(paymentId, text);

    } catch (error: any) {
      console.error('Error processing transaction hash:', error);
      await ctx.reply('❌ Ошибка при обработке транзакции. Обратитесь в поддержку: /support');
    }
  }
});

// Обработка ошибок
bot.catch((err, ctx) => {
  console.error('Error in bot:', err);
  ctx.reply('Произошла ошибка. Попробуйте позже или обратитесь в поддержку: /support');
});

// Запуск бота
bot.launch().then(() => {
  console.log('🤖 Telegram Bot is running...');
});

// Graceful shutdown
process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));

