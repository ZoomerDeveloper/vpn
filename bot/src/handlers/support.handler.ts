import { Context } from 'telegraf';

export async function supportHandler(ctx: Context) {
  const supportUsername = process.env.SUPPORT_USERNAME || '@support';
  
  const message = `
🆘 *Поддержка*

Если у вас возникли вопросы или проблемы, свяжитесь с нами:

${supportUsername}

Или напишите в ответ на это сообщение.
  `;

  await ctx.reply(message, { parse_mode: 'Markdown' });
}

