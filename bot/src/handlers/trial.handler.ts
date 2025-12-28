import { Context } from 'telegraf';
import { BotService } from '../services/bot.service';
import QRCode from 'qrcode';

export async function trialHandler(ctx: Context, botService: BotService) {
  try {
    if (!ctx.from) {
      return;
    }

    const telegramId = ctx.from.id.toString();
    
    let user = await botService.getUserByTelegramId(telegramId);
    
    if (!user) {
      await ctx.reply('Сначала выполните команду /start');
      return;
    }

    if (user.trialUsed) {
      await ctx.reply('❌ Вы уже использовали пробный период. Пожалуйста, купите подписку: /buy');
      return;
    }

    // Запускаем trial
    user = await botService.startTrial(user.id, 24);

    // Создаем peer и получаем конфиг
    const { peer, config } = await botService.createPeer(user.id);

    // Генерируем QR-код
    const qrCodeDataUrl = await QRCode.toDataURL(config);

    const message = `
✅ *Пробный период активирован!*

📅 Действителен до: ${new Date(user.trialExpiresAt!).toLocaleString('ru-RU')}
📱 Устройств: 1/1

*Ваш VPN конфиг готов!*

Ниже вы получите:
• QR-код (для быстрой настройки в приложении WireGuard)
• Файл конфигурации (для ручного импорта)
    `;

    await ctx.reply(message, { parse_mode: 'Markdown' });

    // Отправляем QR-код как фото
    const qrBuffer = Buffer.from(qrCodeDataUrl.split(',')[1], 'base64');
    await ctx.replyWithPhoto(
      { source: qrBuffer },
      {
        caption: '📱 *QR-код для настройки*\n\n⚠️ *Важно:* Используйте встроенный сканер в приложении WireGuard!\n\n1. Откройте приложение WireGuard\n2. Нажмите "+" → "Создать из QR-кода"\n3. Отсканируйте этот QR-код\n\n❌ Не используйте камеру телефона - она откроет текст в браузере!',
        parse_mode: 'Markdown',
      },
    );

    // Отправляем конфиг как файл
    await ctx.replyWithDocument(
      {
        source: Buffer.from(config),
        filename: `vpn-${peer.id.substring(0, 8)}.conf`,
      },
      {
        caption: '📄 *Файл конфигурации WireGuard*\n\n*Как импортировать:*\n1. Скачайте этот файл на устройство\n2. Откройте приложение WireGuard\n3. Нажмите "+" → "Создать из файла или архива"\n4. Выберите этот файл\n\n✅ Это самый простой способ настройки!',
        parse_mode: 'Markdown',
      },
    );

  } catch (error: any) {
    console.error('Error in trial handler:', error);
    await ctx.reply(`❌ Ошибка: ${error.message || 'Неизвестная ошибка'}\n\nОбратитесь в поддержку: /support`);
  }
}

