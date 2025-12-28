# VPN Service - Полное руководство на русском

## Описание проекта

MVP VPN-сервиса с Telegram-ботом для автоматизированной продажи доступа через WireGuard. Проект разработан для рынка РФ с упором на простоту, стабильность и минимальный UX.

## Возможности

### ✅ Реализовано в MVP

1. **Trial система**
   - 24 часа бесплатного доступа
   - 1 устройство
   - Автоматическая деактивация

2. **Платные тарифы**
   - 1 месяц (299₽)
   - 1 год (1999₽)
   - Семейный (3-5 устройств)
   - Гибкая настройка цен и лимитов

3. **Telegram Bot**
   - Простой интерфейс
   - Автоматическая отправка конфигов
   - QR-коды для мобильных устройств
   - Управление устройствами

4. **WireGuard**
   - Автоматическая генерация ключей
   - Поддержка нескольких серверов
   - Балансировка нагрузки
   - Автоматическое управление peers

5. **Платежи**
   - USDT TRC20
   - Проверка транзакций
   - Автоматическая активация

6. **Автоматизация**
   - Проверка истечения подписок
   - Управление устройствами
   - Распределение пользователей

## Архитектура

```
Telegram Bot (Telegraf)
    ↓ HTTP API
Backend API (NestJS)
    ↓
    ├──► PostgreSQL (БД)
    └──► WireGuard Servers (VPN)
```

## Быстрый старт

### 1. Установка зависимостей

```bash
# Backend
cd backend
npm install

# Bot
cd ../bot
npm install
```

### 2. Настройка базы данных

```bash
# Создайте базу данных
createdb vpn_service

# Или через psql
psql -U postgres
CREATE DATABASE vpn_service;
\q
```

### 3. Настройка переменных окружения

**backend/.env:**
```env
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=your_password
DB_DATABASE=vpn_service
TELEGRAM_BOT_TOKEN=your_bot_token
```

**bot/.env:**
```env
TELEGRAM_BOT_TOKEN=your_bot_token
API_BASE_URL=http://localhost:3000
```

### 4. Запуск

```bash
# Терминал 1: Backend
cd backend
npm run start:dev

# Терминал 2: Bot
cd bot
npm run start:dev

# Терминал 3: Заполнение начальных данных
cd backend
ts-node src/database/seeds/seed.ts
```

### 5. Настройка WireGuard сервера

На VPN сервере выполните:
```bash
bash scripts/setup-wireguard.sh
```

Зарегистрируйте сервер через API (см. docs/EXAMPLES.md)

## Документация

- **QUICKSTART.md** - Быстрый старт для разработки
- **DEPLOY.md** - Инструкция по деплою в продакшн
- **ARCHITECTURE.md** - Детальная архитектура системы
- **API.md** - Документация API endpoints
- **EXAMPLES.md** - Примеры использования
- **FEATURES.md** - Список функций и планов

## Основные команды Telegram Bot

- `/start` - Регистрация и главное меню
- `/trial` - Активировать пробный период (24 часа)
- `/buy` - Купить подписку
- `/status` - Проверить статус аккаунта
- `/devices` - Управление устройствами
- `/support` - Связаться с поддержкой

## API Endpoints

### Основные:

- `GET /health` - Проверка работоспособности
- `GET /users/telegram/:telegramId` - Найти пользователя
- `POST /users/:id/trial` - Активировать trial
- `POST /vpn/users/:userId/peers` - Создать VPN peer
- `GET /vpn/peers/:peerId/config` - Получить конфиг
- `POST /payments` - Создать платеж
- `POST /payments/:id/confirm` - Подтвердить платеж
- `GET /tariffs` - Список тарифов

Полная документация: `docs/API.md`

## Структура проекта

```
vpn/
├── backend/          # NestJS API
│   ├── src/
│   │   ├── users/    # Пользователи
│   │   ├── vpn/      # VPN управление
│   │   ├── payments/ # Платежи
│   │   ├── tariffs/  # Тарифы
│   │   ├── wireguard/# WireGuard серверы
│   │   └── tasks/    # Cron задачи
│   └── ...
├── bot/              # Telegram Bot
│   ├── src/
│   │   ├── handlers/ # Обработчики команд
│   │   └── services/ # Сервисы
│   └── ...
├── scripts/          # Утилиты
│   ├── setup-wireguard.sh
│   └── check-payments.ts
└── docs/             # Документация
```

## Технологии

- **Backend:** NestJS, TypeORM, PostgreSQL
- **Bot:** Telegraf (Node.js)
- **VPN:** WireGuard
- **Payments:** USDT TRC20 (TronGrid API)

## Деплой в продакшн

См. подробную инструкцию: `docs/DEPLOY.md`

Основные шаги:
1. Настройка сервера (Ubuntu 20.04+)
2. Установка PostgreSQL
3. Деплой Backend API
4. Деплой Telegram Bot
5. Настройка WireGuard серверов
6. Настройка systemd services
7. Настройка cron для проверки платежей

## Безопасность

⚠️ **Важно для продакшна:**

1. Смените все секретные ключи в `.env`
2. Используйте сильные пароли для БД
3. Настройте firewall (UFW)
4. Используйте HTTPS для API
5. Регулярно обновляйте зависимости
6. Настройте резервное копирование БД

## Поддержка и вопросы

- Изучите документацию в папке `docs/`
- Проверьте примеры в `docs/EXAMPLES.md`
- Для вопросов создавайте issues в репозитории

## Лицензия

MIT

## Благодарности

Проект разработан как MVP для быстрого старта VPN-бизнеса.

