# Исправление проблем при деплое

## Проблема 1: Seed запускается из неправильной директории

Seed находится в `backend/src/database/seeds/seed.ts`, нужно запускать из директории `backend`:

```bash
cd /opt/vpn-service/backend
npx ts-node src/database/seeds/seed.ts
```

Или установить ts-node глобально:
```bash
npm install -g ts-node typescript
ts-node src/database/seeds/seed.ts
```

## Проблема 2: Нет .env.example

Нужно создать .env файл вручную. Содержимое:

### backend/.env

```env
# Server
PORT=3000
NODE_ENV=production

# Database
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=vpn_user
DB_PASSWORD=ваш_пароль_для_vpn_user
DB_DATABASE=vpn_service

# JWT
JWT_SECRET=сгенерируйте-случайную-строку-минимум-32-символа-например-это-очень-длинный-секретный-ключ
JWT_EXPIRES_IN=7d

# Telegram Bot
TELEGRAM_BOT_TOKEN=ваш_telegram_bot_token
TELEGRAM_ADMIN_IDS=ваш_telegram_id

# WireGuard
WG_INTERFACE=wg0
WG_CONFIG_PATH=/etc/wireguard
WG_ALLOWED_IPS=0.0.0.0/0,::/0
WG_DNS=1.1.1.1,8.8.8.8
WG_USE_LOCAL=true

# Payments (USDT TRC20)
USDT_TRC20_ADDRESS=TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t
TRON_API_KEY=
TRON_NETWORK=https://api.trongrid.io

# Trial
TRIAL_DURATION_HOURS=24
TRIAL_DEVICES_LIMIT=1
```

### bot/.env

```env
TELEGRAM_BOT_TOKEN=ваш_telegram_bot_token
API_BASE_URL=http://localhost:3000
SUPPORT_USERNAME=@ваш_username
```

## Быстрые команды для выполнения на сервере:

```bash
# 1. Создать .env для backend
cd /opt/vpn-service/backend
nano .env
# Вставьте содержимое выше, сохраните (Ctrl+O, Enter, Ctrl+X)

# 2. Запустить seed (из директории backend!)
cd /opt/vpn-service/backend
npx ts-node src/database/seeds/seed.ts

# 3. Настроить bot
cd /opt/vpn-service/bot
npm install
npm run build
nano .env
# Вставьте содержимое выше

# 4. Протестировать запуск backend
cd /opt/vpn-service/backend
npm run start:prod
# В другом терминале проверить:
# curl http://localhost:3000/health
```

