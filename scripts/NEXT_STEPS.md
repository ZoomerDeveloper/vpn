# Следующие шаги после настройки сервера

## Что уже сделано ✅

- ✅ Базовая настройка сервера (пакеты, Node.js, PostgreSQL, WireGuard)
- ✅ Настройка PostgreSQL (БД vpn_service, пользователь vpn_user)
- ✅ Настройка firewall

## Что нужно сделать дальше

### Шаг 1: Клонировать репозиторий на сервер

```bash
ssh root@199.247.7.185

# На сервере:
cd /opt
git clone <ваш-repo-url> vpn-service
# или если репозиторий приватный, используйте SSH ключ или токен
```

### Шаг 2: Настроить .env файлы

**Backend .env:**

```bash
cd /opt/vpn-service/backend
cp .env.example .env
nano .env
```

Минимальная настройка `.env`:
```env
# Server
PORT=3000
NODE_ENV=production

# Database
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=vpn_user
DB_PASSWORD=ваш_пароль_который_вы_ввели_для_vpn_user
DB_DATABASE=vpn_service

# JWT
JWT_SECRET=сгенерируйте-случайную-строку-минимум-32-символа
JWT_EXPIRES_IN=7d

# Telegram Bot
TELEGRAM_BOT_TOKEN=ваш_telegram_bot_token_от_BotFather
TELEGRAM_ADMIN_IDS=ваш_telegram_id

# WireGuard
WG_INTERFACE=wg0
WG_CONFIG_PATH=/etc/wireguard
WG_ALLOWED_IPS=0.0.0.0/0,::/0
WG_DNS=1.1.1.1,8.8.8.8
WG_USE_LOCAL=true  # если Application Server и VPN Server на одной машине

# Payments (USDT TRC20)
USDT_TRC20_ADDRESS=ваш_USDT_TRC20_адрес
TRON_API_KEY=ваш_tron_api_key_или_оставьте_пустым
TRON_NETWORK=https://api.trongrid.io

# Trial
TRIAL_DURATION_HOURS=24
TRIAL_DEVICES_LIMIT=1
```

**Bot .env:**

```bash
cd /opt/vpn-service/bot
cp .env.example .env
nano .env
```

Настройка `.env`:
```env
TELEGRAM_BOT_TOKEN=ваш_telegram_bot_token_от_BotFather
API_BASE_URL=http://localhost:3000
SUPPORT_USERNAME=@ваш_username
```

### Шаг 3: Установить зависимости и собрать проект

```bash
# Backend
cd /opt/vpn-service/backend
npm install
npm run build

# Bot
cd /opt/vpn-service/bot
npm install
npm run build
```

### Шаг 4: Инициализировать базу данных

```bash
cd /opt/vpn-service/backend

# Если используете TypeORM с synchronize=true (только для разработки)
# Просто запустите приложение, таблицы создадутся автоматически

# Или запустите миграции (если настроены)
npm run migration:run

# Заполните начальные данные (тарифы)
ts-node src/database/seeds/seed.ts
```

### Шаг 5: Тестовый запуск

```bash
# В одном терминале - Backend
cd /opt/vpn-service/backend
npm run start:prod

# В другом терминале (откройте новую SSH сессию) - Bot
cd /opt/vpn-service/bot
npm run start

# Проверьте что всё работает
curl http://localhost:3000/health
```

### Шаг 6: Настроить systemd services для автозапуска

**Backend service:**

```bash
sudo nano /etc/systemd/system/vpn-backend.service
```

Содержимое:
```ini
[Unit]
Description=VPN Service Backend API
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vpn-service/backend
ExecStart=/usr/bin/node dist/main.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

**Bot service:**

```bash
sudo nano /etc/systemd/system/vpn-bot.service
```

Содержимое:
```ini
[Unit]
Description=VPN Service Telegram Bot
After=network.target vpn-backend.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vpn-service/bot
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Запуск services:**

```bash
# Перезагрузить systemd
sudo systemctl daemon-reload

# Включить автозапуск
sudo systemctl enable vpn-backend
sudo systemctl enable vpn-bot

# Запустить сервисы
sudo systemctl start vpn-backend
sudo systemctl start vpn-bot

# Проверить статус
sudo systemctl status vpn-backend
sudo systemctl status vpn-bot

# Просмотр логов
sudo journalctl -u vpn-backend -f
sudo journalctl -u vpn-bot -f
```

### Шаг 7: Настроить WireGuard (если это VPN сервер)

Если этот сервер будет использоваться как WireGuard VPN сервер:

```bash
cd /opt/vpn-service
bash scripts/setup-wireguard.sh
```

Затем зарегистрируйте сервер через API или создайте вручную через API endpoint.

### Шаг 8: Настроить cron для проверки платежей (опционально)

```bash
crontab -e
```

Добавьте:
```
*/5 * * * * cd /opt/vpn-service/scripts && /usr/bin/node check-payments.ts >> /var/log/vpn-payments.log 2>&1
```

## Быстрая проверка

После всех шагов проверьте:

```bash
# Backend работает?
curl http://localhost:3000/health

# Сервисы запущены?
sudo systemctl status vpn-backend
sudo systemctl status vpn-bot

# Логи без ошибок?
sudo journalctl -u vpn-backend --no-pager -n 50
sudo journalctl -u vpn-bot --no-pager -n 50
```

## Полезные команды

```bash
# Перезапустить сервисы
sudo systemctl restart vpn-backend
sudo systemctl restart vpn-bot

# Остановить сервисы
sudo systemctl stop vpn-backend
sudo systemctl stop vpn-bot

# Просмотр логов в реальном времени
sudo journalctl -u vpn-backend -f
sudo journalctl -u vpn-bot -f

# Проверка подключения к БД
sudo -u postgres psql -d vpn_service -U vpn_user
```

