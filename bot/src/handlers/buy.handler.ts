import { Context, Markup } from 'telegraf';
import { BotService } from '../services/bot.service';

export async function buyHandler(ctx: Context, botService: BotService) {
  try {
    const tariffs = await botService.getTariffs();

    if (tariffs.length === 0) {
      await ctx.reply('❌ Тарифы временно недоступны. Обратитесь в поддержку: /support');
      return;
    }

    const keyboard = tariffs.map((tariff) => [
      Markup.button.callback(
        `${tariff.name} - ${tariff.price} ${tariff.currency}`,
        `tariff:${tariff.id}`,
      ),
    ]);

    const message = `
💰 *Выберите тариф:*

${tariffs.map((tariff) => 
  `*${tariff.name}*\n` +
  `${tariff.description || ''}\n` +
  `💵 ${tariff.price} ${tariff.currency}\n` +
  `📅 ${tariff.durationDays} ${tariff.durationDays === 1 ? 'день' : tariff.durationDays < 5 ? 'дня' : 'дней'}\n` +
  `📱 До ${tariff.devicesLimit} устройств\n`
).join('\n')}
    `;

    await ctx.reply(message, {
      parse_mode: 'Markdown',
      ...Markup.inlineKeyboard(keyboard),
    });
  } catch (error: any) {
    console.error('Error in buy handler:', error);
    await ctx.reply('❌ Ошибка при загрузке тарифов. Попробуйте позже или обратитесь в поддержку: /support');
  }
}

export async function tariffCallbackHandler(ctx: Context, botService: BotService) {
  try {
    await ctx.answerCbQuery();

    if (!ctx.from) {
      return;
    }

    const match = 'match' in ctx && ctx.match;
    if (!match || !Array.isArray(match) || match.length < 2) {
      return;
    }

    const tariffId = match[1];
    const telegramId = ctx.from.id.toString();

    let user = await botService.getUserByTelegramId(telegramId);
    if (!user) {
      user = await botService.createUser(telegramId, {
        username: ctx.from.username,
        firstName: ctx.from.first_name,
        lastName: ctx.from.last_name,
      });
    }

    // Создаем платеж
    const payment = await botService.createPayment(user.id, tariffId);
    const { address, amount } = await botService.getPaymentAddress(payment.id);

    const message = `
💳 *Оплата USDT (TRC20)*

💰 Сумма: *${amount} USDT*
📝 ID платежа: \`${payment.id.substring(0, 8)}\`

📤 *Адрес для оплаты:*
\`${address}\`

*Инструкция:*
1. Отправьте ${amount} USDT (TRC20) на указанный адрес
2. После отправки транзакции, отправьте хеш транзакции в ответ на это сообщение
3. После подтверждения платежа вы получите конфигурацию VPN

⚠️ *Важно:* Отправляйте точную сумму ${amount} USDT
    `;

    await ctx.editMessageText(message, {
      parse_mode: 'Markdown',
      ...Markup.inlineKeyboard([
        [Markup.button.callback('✅ Я оплатил, ввести хеш транзакции', `payment_hash:${payment.id}`)],
        [Markup.button.callback('❌ Отмена', 'cancel_payment')],
      ]),
    });

    // Сохраняем paymentId в контексте для последующей обработки
    // В реальном приложении лучше использовать базу данных для хранения состояний
    (ctx as any).session = (ctx as any).session || {};
    (ctx as any).session.waitingForHash = payment.id;

  } catch (error: any) {
    console.error('Error in tariff callback:', error);
    await ctx.answerCbQuery('Ошибка при создании платежа');
    await ctx.reply('❌ Ошибка при создании платежа. Попробуйте позже или обратитесь в поддержку: /support');
  }
}

