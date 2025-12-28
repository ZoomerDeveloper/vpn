import { Context, Markup } from 'telegraf';
import { BotService } from '../services/bot.service';
import QRCode from 'qrcode';

export async function myDevicesHandler(ctx: Context, botService: BotService) {
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

    if (user.status === 'expired' || user.status === 'blocked') {
      await ctx.reply('❌ Ваша подписка неактивна. Купите подписку: /buy');
      return;
    }

    const peers = await botService.getUserPeers(user.id);

    if (peers.length === 0) {
      const message = `
📱 *Мои устройства*

У вас пока нет активных устройств.

Создать новое устройство: /trial
      `;
      await ctx.reply(message, { parse_mode: 'Markdown' });
      return;
    }

    const keyboard = peers.map((peer) => [
      Markup.button.callback(
        `📱 ${peer.allocatedIp} ${peer.isActive ? '✅' : '❌'}`,
        `peer_info:${peer.id}`,
      ),
    ]);

    const message = `
📱 *Мои устройства*

Найдено устройств: ${peers.length}

Выберите устройство для просмотра конфигурации:
    `;

    await ctx.reply(message, {
      parse_mode: 'Markdown',
      ...Markup.inlineKeyboard(keyboard),
    });
  } catch (error: any) {
    console.error('Error in devices handler:', error);
    await ctx.reply('❌ Ошибка при получении списка устройств. Попробуйте позже или обратитесь в поддержку: /support');
  }
}

export async function deviceCallbackHandler(ctx: Context, botService: BotService) {
  try {
    await ctx.answerCbQuery();

    const match = 'match' in ctx && ctx.match;
    if (!match || !Array.isArray(match) || match.length < 2) {
      return;
    }

    const peerId = match[1];
    const config = await botService.getPeerConfig(peerId);

    // Убеждаемся что config - это строка (не объект)
    const configString = typeof config === 'string' ? config : String(config);

    // Генерируем QR-код из текстовой конфигурации
    const qrCodeDataUrl = await QRCode.toDataURL(configString, {
      type: 'image/png',
      errorCorrectionLevel: 'M',
      margin: 1,
    });
    const qrBuffer = Buffer.from(qrCodeDataUrl.split(',')[1], 'base64');

    // Отправляем QR-код
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
        filename: `vpn-${peerId.substring(0, 8)}.conf`,
      },
      {
        caption: '📄 Файл конфигурации WireGuard',
        ...Markup.inlineKeyboard([
          [Markup.button.callback('🗑️ Удалить устройство', `peer_delete:${peerId}`)],
        ]),
      },
    );
  } catch (error: any) {
    console.error('Error in device callback:', error);
    await ctx.answerCbQuery('Ошибка при получении конфигурации');
    await ctx.reply('❌ Ошибка при получении конфигурации устройства.');
  }
}

