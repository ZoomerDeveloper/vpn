# Быстрый старт для разработки

## Предварительные требования

- Node.js 18+
- PostgreSQL 14+
- Telegram Bot Token (получить у @BotFather)
- WireGuard установлен (опционально для локальной разработки)

## Шаг 1: Настройка базы данных

```bash
# Создайте базу данных
createdb vpn_service

# Или через psql
psql -U postgres
CREATE DATABASE vpn_service;
\q
```

## Шаг 2: Настройка Backend

```bash
cd backend

# Установите зависимости
npm install

# Создайте .env файл
cp .env.example .env

# Отредактируйте .env (укажите настройки БД и другие параметры)
nano .env
```

Минимальные настройки в `.env`:
```env
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=your_password
DB_DATABASE=vpn_service
JWT_SECRET=your-secret-key
TELEGRAM_BOT_TOKEN=your-bot-token
```

```bash
# Запустите приложение (автоматически создаст таблицы если synchronize=true)
npm run start:dev

# В другом терминале, заполните начальные данные
ts-node src/database/seeds/seed.ts
```

Backend должен запуститься на `http://localhost:3000`

## Шаг 3: Настройка Telegram Bot

```bash
cd bot

# Установите зависимости
npm install

# Создайте .env файл
cp .env.example .env

# Отредактируйте .env
nano .env
```

Минимальные настройки:
```env
TELEGRAM_BOT_TOKEN=your-bot-token
API_BASE_URL=http://localhost:3000
SUPPORT_USERNAME=@your_username
```

```bash
# Запустите бота
npm run start:dev
```

## Шаг 4: Настройка WireGuard сервера (опционально)

Для локальной разработки можно пропустить этот шаг или использовать Docker.

### Вариант 1: Локальный WireGuard (Linux/Mac)

```bash
# Установите WireGuard
sudo apt install wireguard  # Ubuntu/Debian
# или
brew install wireguard-tools  # macOS

# Запустите скрипт настройки (на сервере, не локально!)
# bash scripts/setup-wireguard.sh
```

### Вариант 2: Docker (для тестирования)

```bash
# Используйте готовый образ WireGuard
docker run -d \
  --name=wireguard \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/Moscow \
  -e SERVERURL=your-server-ip \
  -e SERVERPORT=51820 \
  -p 51820:51820/udp \
  -v /path/to/config:/config \
  linuxserver/wireguard
```

### Регистрация сервера в Backend

После настройки WireGuard сервера, зарегистрируйте его через API:

```bash
curl -X POST http://localhost:3000/wireguard/servers \
  -H "Content-Type: application/json" \
  -d '{
    "name": "local-server",
    "host": "localhost",
    "port": 51820,
    "publicIp": "127.0.0.1",
    "privateIp": "10.0.0.1",
    "endpoint": "127.0.0.1",
    "network": "10.0.0.0/24",
    "dns": "1.1.1.1,8.8.8.8",
    "publicKey": "YOUR_SERVER_PUBLIC_KEY",
    "privateKey": "YOUR_SERVER_PRIVATE_KEY"
  }'
```

**Важно:** Для локальной разработки установите в `.env`:
```env
WG_USE_LOCAL=true
```

## Шаг 5: Тестирование

1. Откройте Telegram и найдите вашего бота
2. Отправьте `/start`
3. Попробуйте `/trial` для активации пробного периода
4. Проверьте, что конфиг WireGuard был отправлен

## Проверка работы API

```bash
# Health check
curl http://localhost:3000/health

# Получить тарифы
curl http://localhost:3000/tariffs

# Получить пользователей
curl http://localhost:3000/users
```

## Структура проекта для разработки

Рекомендуемая структура:
```
vpn/
├── backend/
│   ├── src/
│   ├── .env
│   └── package.json
├── bot/
│   ├── src/
│   ├── .env
│   └── package.json
└── docs/
```

## Полезные команды

### Backend
```bash
npm run start:dev      # Запуск с hot-reload
npm run build          # Сборка
npm run start:prod     # Продакшн запуск
npm run migration:run  # Применить миграции
```

### Bot
```bash
npm run start:dev      # Запуск с hot-reload
npm run build          # Сборка
npm run start          # Продакшн запуск
```

## Отладка

### Логи Backend
Логи выводятся в консоль. Для более детального логирования можно настроить NestJS Logger.

### Логи Bot
Логи бота также выводятся в консоль. Ошибки Telegram API будут видны здесь.

### Проблемы с подключением

1. **Bot не отвечает:**
   - Проверьте TELEGRAM_BOT_TOKEN
   - Проверьте, что бот запущен
   - Проверьте логи

2. **API недоступен:**
   - Проверьте, что Backend запущен на порту 3000
   - Проверьте API_BASE_URL в .env бота
   - Проверьте CORS настройки

3. **База данных:**
   - Проверьте подключение к PostgreSQL
   - Убедитесь, что база данных создана
   - Проверьте credentials в .env

4. **WireGuard:**
   - Для локальной разработки можно использовать WG_USE_LOCAL=true
   - Или просто пропустить WireGuard и тестировать API

## Следующие шаги

- Изучите `docs/API.md` для понимания всех endpoints
- Посмотрите `docs/EXAMPLES.md` для примеров использования
- Прочитайте `docs/ARCHITECTURE.md` для понимания архитектуры
- Для деплоя в продакшн см. `docs/DEPLOY.md`

