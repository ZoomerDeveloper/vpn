import { Context } from 'telegraf';
import { BotService } from '../services/bot.service';

export async function statusHandler(ctx: Context, botService: BotService) {
  try {
    if (!ctx.from) {
      return;
    }

    const telegramId = ctx.from.id.toString();
    
    const user = await botService.getUserByTelegramId(telegramId);
    
    if (!user) {
      await ctx.reply('Сначала выполните команду /start');
      return;
    }

    let statusText = '';
    switch (user.status) {
      case 'active':
        statusText = '✅ Активна';
        break;
      case 'trial':
        statusText = '🆓 Пробный период';
        break;
      case 'expired':
        statusText = '❌ Истекла';
        break;
      case 'blocked':
        statusText = '🚫 Заблокирована';
        break;
      default:
        statusText = '❓ Не определена';
    }

    const expireAt = user.expireAt 
      ? new Date(user.expireAt).toLocaleString('ru-RU')
      : 'Не установлено';

    const trialExpiresAt = user.trialExpiresAt
      ? new Date(user.trialExpiresAt).toLocaleString('ru-RU')
      : null;

    let message = `
📊 *Ваш статус*

*Статус:* ${statusText}
`;

    if (user.status === 'active' || user.status === 'trial') {
      message += `*Действует до:* ${user.status === 'trial' && trialExpiresAt ? trialExpiresAt : expireAt}\n`;
    }

    if (user.trialUsed) {
      message += `*Пробный период:* Использован\n`;
    } else {
      message += `*Пробный период:* Доступен\n`;
    }

    message += `\n/start - Главное меню\n/buy - Купить подписку\n/devices - Мои устройства`;

    await ctx.reply(message, { parse_mode: 'Markdown' });
  } catch (error: any) {
    console.error('Error in status handler:', error);
    await ctx.reply('❌ Ошибка при получении статуса. Попробуйте позже или обратитесь в поддержку: /support');
  }
}

