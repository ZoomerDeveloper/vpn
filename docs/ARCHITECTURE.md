# Архитектура VPN сервиса

## Общая схема

```
┌─────────────────────────────────────────────────────────┐
│                    Telegram Bot                         │
│                  (Telegraf / Node.js)                   │
└──────────────────────┬──────────────────────────────────┘
                       │ HTTP API
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   Backend API                           │
│                   (NestJS)                              │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │  Users   │  │   VPN    │  │ Payments │            │
│  │  Module  │  │  Module  │  │  Module  │            │
│  └──────────┘  └──────────┘  └──────────┘            │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │ Tariffs  │  │WireGuard │  │  Tasks   │            │
│  │  Module  │  │  Module  │  │  Module  │            │
│  └──────────┘  └──────────┘  └──────────┘            │
└──────┬───────────────────┬────────────────────────────┘
       │                   │
       ▼                   ▼
┌──────────────┐   ┌──────────────┐
│  PostgreSQL  │   │ WireGuard    │
│  Database    │   │   Servers    │
└──────────────┘   └──────────────┘
```

## Компоненты системы

### 1. Telegram Bot (`bot/`)

**Технологии:** Telegraf, Node.js, TypeScript

**Основные функции:**
- Обработка команд пользователей
- Отправка WireGuard конфигураций
- Генерация QR-кодов
- Обработка платежей

**Handlers:**
- `start.handler.ts` - Регистрация/приветствие
- `trial.handler.ts` - Активация пробного периода
- `buy.handler.ts` - Покупка подписки
- `status.handler.ts` - Статус пользователя
- `devices.handler.ts` - Управление устройствами
- `support.handler.ts` - Поддержка

### 2. Backend API (`backend/`)

**Технологии:** NestJS, TypeORM, PostgreSQL, TypeScript

#### Модули:

##### Users Module
- Управление пользователями
- Статусы: ACTIVE, TRIAL, EXPIRED, BLOCKED
- Trial система
- Активация подписок

##### VPN Module
- Управление VPN peers
- Создание/деактивация peers
- Генерация конфигураций
- Проверка лимитов устройств

##### WireGuard Module
- Генерация ключей (wg genkey/pubkey)
- Управление peers на серверах (wg set)
- Выделение IP адресов
- Балансировка нагрузки между серверами

##### Payments Module
- Создание платежей
- Интеграция с USDT TRC20
- Проверка транзакций через TronGrid API
- Активация подписок после оплаты

##### Tariffs Module
- Управление тарифами
- Лимиты устройств
- Цены и длительность

##### Tasks Module
- Cron задачи
- Автоматическая проверка истечения подписок
- Проверка платежей

### 3. База данных (PostgreSQL)

#### Таблицы:

**users**
- id (UUID)
- telegramId (unique)
- status (enum)
- tariffId
- expireAt
- trialUsed, trialStartedAt, trialExpiresAt

**vpn_peers**
- id (UUID)
- userId
- serverId
- publicKey (unique)
- privateKey
- presharedKey
- allocatedIp
- isActive

**payments**
- id (UUID)
- userId
- tariffId
- amount
- currency
- status (enum)
- provider (enum)
- transactionHash

**tariffs**
- id (UUID)
- name
- price
- durationDays
- devicesLimit
- isActive

**vpn_servers**
- id (UUID)
- name
- host, port
- publicIp, privateIp
- endpoint
- network
- publicKey, privateKey
- currentPeers, maxPeers

## Потоки данных

### 1. Регистрация и Trial

```
User → /start → Bot → API: getUserByTelegramId()
  ↓ (пользователь не найден)
Bot → API: createUser()
  ↓
User → /trial → Bot → API: startTrial()
  ↓
Bot → API: createPeer()
  ↓
API → WireGuard: generateKeyPair()
API → WireGuard: addPeer()
API → generateConfig()
  ↓
Bot ← API: config
  ↓
Bot: generateQRCode()
Bot → User: отправка конфига + QR
```

### 2. Покупка подписки

```
User → /buy → Bot → API: getTariffs()
  ↓
Bot → User: список тарифов (inline keyboard)
  ↓
User → выбор тарифа → Bot → API: createPayment()
  ↓
Bot → API: generatePaymentAddress()
  ↓
Bot → User: адрес для оплаты USDT
  ↓
User → отправляет USDT → получает transactionHash
  ↓
User → отправляет hash → Bot → API: confirmPayment()
  ↓
API → TronGrid: проверка транзакции
  ↓
API → activateSubscription()
API → createPeer()
  ↓
Bot → User: конфиг VPN
```

### 3. Автоматическое истечение

```
Cron (каждый час) → Tasks: handleExpiration()
  ↓
UsersService: checkExpiration()
  ↓
SQL: SELECT * WHERE expireAt < NOW() AND status IN ('active', 'trial')
  ↓
Обновление статуса на 'expired'
```

## Безопасность

1. **Ключи WireGuard:**
   - Приватные ключи хранятся в БД (зашифрованы)
   - Публичные ключи используются для конфигов
   - Preshared keys для дополнительной безопасности

2. **База данных:**
   - Использование TypeORM для защиты от SQL injection
   - Валидация входных данных через class-validator

3. **API:**
   - CORS настройки
   - Rate limiting (рекомендуется добавить)

4. **WireGuard серверы:**
   - Доступ только с Application Server
   - Firewall правила

## Масштабирование

### Горизонтальное масштабирование WireGuard

Система поддерживает несколько WireGuard серверов:
- Автоматический выбор сервера с наименьшей загрузкой
- Распределение пользователей между серверами
- Независимое управление каждым сервером

### Вертикальное масштабирование Backend

- Можно запустить несколько инстансов backend за load balancer
- PostgreSQL может быть вынесен на отдельный сервер
- Stateless архитектура (все состояние в БД)

## API Endpoints

### Users
- `GET /users` - список пользователей
- `GET /users/:id` - информация о пользователе
- `GET /users/telegram/:telegramId` - найти по Telegram ID
- `POST /users` - создать пользователя
- `POST /users/:id/trial` - активировать trial

### VPN
- `POST /vpn/users/:userId/peers` - создать peer
- `GET /vpn/users/:userId/peers` - список peers пользователя
- `GET /vpn/peers/:peerId/config` - получить конфиг
- `PATCH /vpn/peers/:peerId/deactivate` - деактивировать peer
- `PATCH /vpn/peers/:peerId/activate` - активировать peer

### Payments
- `POST /payments` - создать платеж
- `GET /payments/:id` - информация о платеже
- `GET /payments/pending` - ожидающие платежи
- `POST /payments/:id/address` - получить адрес для оплаты
- `POST /payments/:id/confirm` - подтвердить платеж

### Tariffs
- `GET /tariffs` - список активных тарифов
- `GET /tariffs/:id` - информация о тарифе
- `POST /tariffs` - создать тариф (admin)
- `PATCH /tariffs/:id` - обновить тариф (admin)

### WireGuard
- `GET /wireguard/servers` - список серверов
- `POST /wireguard/servers` - добавить сервер
- `POST /wireguard/servers/:serverId/peers` - добавить peer на сервер
- `DELETE /wireguard/servers/:serverId/peers/:publicKey` - удалить peer

## Интеграции

### USDT TRC20
- Использование TronGrid API для проверки транзакций
- Поддержка TRC20 токенов
- Автоматическая проверка платежей через cron

### Telegram
- Telegram Bot API через Telegraf
- Inline keyboards для навигации
- Отправка файлов и QR-кодов

## Логирование

- Логи всех операций через NestJS Logger
- Отдельные логи для WireGuard операций
- Логи платежей в отдельный файл

## Мониторинг

Рекомендуется добавить:
- Health checks (`/health`)
- Метрики (Prometheus)
- Алерты на критические ошибки
- Мониторинг нагрузки на WireGuard серверы

