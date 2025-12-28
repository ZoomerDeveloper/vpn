import { Context } from 'telegraf';
import { BotService } from '../services/bot.service';

export async function startHandler(ctx: Context, botService: BotService) {
  try {
    const telegramId = ctx.from.id.toString();
    const username = ctx.from.username;
    const firstName = ctx.from.first_name;
    const lastName = ctx.from.last_name;

    // Проверяем или создаем пользователя
    let user = await botService.getUserByTelegramId(telegramId);
    
    if (!user) {
      user = await botService.createUser(telegramId, {
        username,
        firstName,
        lastName,
      });
    }

    const welcomeMessage = `
🔐 *Добро пожаловать в VPN сервис!*

Выберите действие:

/start - Главное меню
/trial - Попробовать бесплатно (24 часа)
/buy - Купить подписку
/status - Мой статус
/devices - Мои устройства
/support - Поддержка

*Ваш статус:* ${user.status === 'trial' ? 'Пробный период' : user.status === 'active' ? 'Активна' : 'Не активна'}
    `;

    await ctx.reply(welcomeMessage, { parse_mode: 'Markdown' });
  } catch (error: any) {
    console.error('Error in start handler:', error);
    await ctx.reply('Произошла ошибка. Попробуйте позже или обратитесь в поддержку: /support');
  }
}

