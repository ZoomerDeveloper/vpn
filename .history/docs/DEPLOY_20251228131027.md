# Инструкция по деплою VPN сервиса

## Требования

- **ОС:** Ubuntu 22.04 LTS (рекомендуется) или Ubuntu 20.04 LTS
- Node.js 18+
- PostgreSQL 14+
- WireGuard установлен на VPN-серверах
- Telegram Bot Token

> 💡 Подробнее о выборе ОС см. [OS_RECOMMENDATIONS.md](OS_RECOMMENDATIONS.md)

## Архитектура деплоя

```
┌─────────────────┐
│  Application    │  Backend API + Telegram Bot
│     Server      │  PostgreSQL
└────────┬────────┘
         │
         ├─────────► WireGuard Server 1
         ├─────────► WireGuard Server 2
         └─────────► ... (дополнительные серверы)
```

## Шаг 1: Подготовка Application Server

### 1.1 Установка зависимостей

```bash
# Обновляем систему
sudo apt update && sudo apt upgrade -y

# Устанавливаем Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Устанавливаем PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Устанавливаем необходимые пакеты
sudo apt install -y git build-essential
```

### 1.2 Настройка PostgreSQL

```bash
# Переключаемся на пользователя postgres
sudo -u postgres psql

# В psql выполняем:
CREATE DATABASE vpn_service;
CREATE USER vpn_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE vpn_service TO vpn_user;
\q
```

## Шаг 2: Деплой Backend API

### 2.1 Клонирование и установка

```bash
# Создаем директорию проекта
cd /opt
sudo git clone <your-repo-url> vpn-service
cd vpn-service

# Устанавливаем зависимости
cd backend
npm install

# Создаем .env файл
cp .env.example .env
nano .env
```

### 2.2 Настройка .env

```env
# Server
PORT=3000
NODE_ENV=production

# Database
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=vpn_user
DB_PASSWORD=your_secure_password
DB_DATABASE=vpn_service

# JWT
JWT_SECRET=your-very-secure-secret-key-min-32-chars
JWT_EXPIRES_IN=7d

# Telegram Bot
TELEGRAM_BOT_TOKEN=your-telegram-bot-token
TELEGRAM_ADMIN_IDS=your-telegram-id

# WireGuard
WG_INTERFACE=wg0
WG_CONFIG_PATH=/etc/wireguard
WG_SERVERS=server1:10.0.0.1:51820
WG_ALLOWED_IPS=0.0.0.0/0,::/0
WG_DNS=1.1.1.1,8.8.8.8

# Payments (USDT TRC20)
USDT_TRC20_ADDRESS=TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t
TRON_API_KEY=your-tron-api-key
TRON_NETWORK=https://api.trongrid.io

# Trial
TRIAL_DURATION_HOURS=24
TRIAL_DEVICES_LIMIT=1
```

### 2.3 Сборка и запуск

```bash
# Собираем проект
npm run build

# Инициализируем базу данных (создание таблиц)
npm run migration:run

# Заполняем тарифы
ts-node src/database/seeds/seed.ts

# Тестовый запуск
npm run start:prod
```

### 2.4 Настройка systemd service

```bash
sudo nano /etc/systemd/system/vpn-backend.service
```

Содержимое файла:

```ini
[Unit]
Description=VPN Service Backend API
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/vpn-service/backend
ExecStart=/usr/bin/node dist/main.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

```bash
# Перезагружаем systemd и запускаем сервис
sudo systemctl daemon-reload
sudo systemctl enable vpn-backend
sudo systemctl start vpn-backend
sudo systemctl status vpn-backend
```

## Шаг 3: Деплой Telegram Bot

### 3.1 Установка и настройка

```bash
cd /opt/vpn-service/bot
npm install

# Создаем .env
cp .env.example .env
nano .env
```

`.env` для бота:

```env
TELEGRAM_BOT_TOKEN=your-telegram-bot-token
API_BASE_URL=http://localhost:3000
SUPPORT_USERNAME=@your_support_username
```

### 3.2 Сборка и запуск

```bash
npm run build

# Тестовый запуск
npm run start
```

### 3.3 Systemd service для бота

```bash
sudo nano /etc/systemd/system/vpn-bot.service
```

```ini
[Unit]
Description=VPN Service Telegram Bot
After=network.target vpn-backend.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/vpn-service/bot
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable vpn-bot
sudo systemctl start vpn-bot
sudo systemctl status vpn-bot
```

## Шаг 4: Настройка WireGuard серверов

### 4.1 На каждом VPN-сервере

```bash
# Загружаем скрипт
wget https://your-domain.com/scripts/setup-wireguard.sh
chmod +x setup-wireguard.sh
sudo ./setup-wireguard.sh
```

Скрипт автоматически:
- Установит WireGuard
- Сгенерирует ключи сервера
- Настроит интерфейс wg0
- Включит IP forwarding
- Настроит iptables для NAT

### 4.2 Регистрация сервера в Backend

После установки WireGuard, зарегистрируйте сервер через API:

```bash
curl -X POST http://your-backend-url:3000/wireguard/servers \
  -H "Content-Type: application/json" \
  -d '{
    "name": "server1",
    "host": "your-server-ip",
    "port": 51820,
    "publicIp": "your-server-public-ip",
    "privateIp": "10.0.0.1",
    "endpoint": "your-server-public-ip",
    "network": "10.0.0.0/24",
    "dns": "1.1.1.1,8.8.8.8",
    "publicKey": "server-public-key-from-setup",
    "privateKey": "server-private-key-from-setup"
  }'
```

**Важно:** Private key сервера должен храниться только на VPN-сервере. В backend достаточно публичного ключа для генерации конфигов клиентов.

## Шаг 5: Настройка Nginx (опционально)

Если нужен HTTPS и reverse proxy:

```bash
sudo apt install -y nginx certbot python3-certbot-nginx

sudo nano /etc/nginx/sites-available/vpn-api
```

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/vpn-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo certbot --nginx -d api.yourdomain.com
```

## Шаг 6: Настройка Cron для проверки платежей

```bash
# Устанавливаем зависимости для скрипта проверки платежей
cd /opt/vpn-service/scripts
npm install

# Добавляем в crontab
crontab -e
```

Добавляем строку:

```
*/5 * * * * cd /opt/vpn-service/scripts && /usr/bin/node check-payments.ts >> /var/log/vpn-payments.log 2>&1
```

## Шаг 7: Настройка файрвола

```bash
# UFW
sudo ufw allow 22/tcp
sudo ufw allow 3000/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 51820/udp  # WireGuard
sudo ufw enable
```

## Шаг 8: Мониторинг и логи

```bash
# Логи backend
sudo journalctl -u vpn-backend -f

# Логи бота
sudo journalctl -u vpn-bot -f

# Логи WireGuard
sudo journalctl -u wg-quick@wg0 -f

# Логи платежей
tail -f /var/log/vpn-payments.log
```

## Проверка работы

1. Проверьте статус сервисов:
   ```bash
   sudo systemctl status vpn-backend
   sudo systemctl status vpn-bot
   sudo systemctl status wg-quick@wg0
   ```

2. Проверьте API:
   ```bash
   curl http://localhost:3000/health
   ```

3. Проверьте бота в Telegram:
   - Отправьте /start боту
   - Попробуйте /trial

## Добавление дополнительных VPN-серверов

1. Установите WireGuard на новом сервере (шаг 4.1)
2. Зарегистрируйте сервер через API (шаг 4.2)
3. Система автоматически будет распределять пользователей между серверами

## Резервное копирование

Рекомендуется настроить регулярное резервное копирование БД:

```bash
# Добавить в crontab
0 2 * * * pg_dump -U vpn_user vpn_service > /backup/vpn_service_$(date +\%Y\%m\%d).sql
```

## Масштабирование

Для масштабирования:
- Добавьте больше WireGuard серверов
- Используйте load balancer для backend (если нужно)
- Настройте репликацию PostgreSQL (для высоких нагрузок)

