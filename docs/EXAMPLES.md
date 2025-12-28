# Примеры использования

## 1. Создание пользователя

### Через API:

```bash
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "telegramId": "123456789",
    "username": "user123",
    "firstName": "Иван",
    "lastName": "Иванов"
  }'
```

### Через Telegram Bot:

Пользователь отправляет `/start` в бота. Бот автоматически создает пользователя если его нет.

## 2. Генерация VPN конфига

### Через API:

```bash
# 1. Активировать trial (если нужно)
curl -X POST http://localhost:3000/users/USER_ID/trial \
  -H "Content-Type: application/json" \
  -d '{"hours": 24}'

# 2. Создать peer и получить конфиг
curl -X POST http://localhost:3000/vpn/users/USER_ID/peers \
  -H "Content-Type: application/json"
```

Response:
```json
{
  "peer": {
    "id": "uuid",
    "publicKey": "abc123...",
    "allocatedIp": "10.0.0.2/32",
    "isActive": true
  },
  "config": "[Interface]\nPrivateKey = xyz789...\nAddress = 10.0.0.2/32\n..."
}
```

### Через Telegram Bot:

Пользователь отправляет `/trial` или `/buy` и выбирает тариф. Бот автоматически создает peer и отправляет конфиг.

## 3. Обработка оплаты

### Сценарий:

1. Пользователь выбирает тариф в боте
2. Создается платеж:

```bash
curl -X POST http://localhost:3000/payments \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-uuid",
    "tariffId": "tariff-uuid",
    "provider": "usdt_trc20"
  }'
```

3. Получаем адрес для оплаты:

```bash
curl -X POST http://localhost:3000/payments/PAYMENT_ID/address
```

Response:
```json
{
  "address": "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
  "amount": 10.5
}
```

4. Пользователь отправляет USDT на адрес и получает transaction hash
5. Подтверждаем платеж:

```bash
curl -X POST http://localhost:3000/payments/PAYMENT_ID/confirm \
  -H "Content-Type: application/json" \
  -d '{
    "transactionHash": "abc123def456..."
  }'
```

6. После подтверждения автоматически:
   - Активируется подписка пользователя
   - Создается VPN peer
   - Пользователь получает конфиг

## 4. Добавление WireGuard сервера

### Через скрипт:

На VPN сервере выполните:
```bash
bash scripts/setup-wireguard.sh
```

Скрипт выведет информацию о сервере (public key, IP и т.д.)

### Через API:

```bash
curl -X POST http://localhost:3000/wireguard/servers \
  -H "Content-Type: application/json" \
  -d '{
    "name": "server1",
    "host": "vpn.example.com",
    "port": 51820,
    "publicIp": "1.2.3.4",
    "privateIp": "10.0.0.1",
    "endpoint": "1.2.3.4",
    "network": "10.0.0.0/24",
    "dns": "1.1.1.1,8.8.8.8",
    "publicKey": "SERVER_PUBLIC_KEY_FROM_SETUP_SCRIPT",
    "privateKey": "SERVER_PRIVATE_KEY_FROM_SETUP_SCRIPT"
  }'
```

**Примечание:** В продакшене private key должен храниться только на VPN сервере. В backend достаточно публичного ключа для генерации клиентских конфигов.

## 5. Управление тарифами

### Создать тариф:

```bash
curl -X POST http://localhost:3000/tariffs \
  -H "Content-Type: application/json" \
  -d '{
    "name": "1 месяц",
    "description": "Базовый тариф на 1 месяц",
    "price": 299,
    "currency": "RUB",
    "durationDays": 30,
    "devicesLimit": 1
  }'
```

### Получить все тарифы:

```bash
curl http://localhost:3000/tariffs
```

## 6. Управление устройствами пользователя

### Получить список устройств:

```bash
curl http://localhost:3000/vpn/users/USER_ID/peers
```

### Деактивировать устройство:

```bash
curl -X PATCH http://localhost:3000/vpn/peers/PEER_ID/deactivate \
  -H "Content-Type: application/json" \
  -d '{"userId": "USER_ID"}'
```

### Получить конфиг устройства:

```bash
curl http://localhost:3000/vpn/peers/PEER_ID/config
```

## 7. Автоматическая проверка платежей

Настройте cron для проверки платежей каждые 5 минут:

```bash
*/5 * * * * cd /opt/vpn-service/scripts && /usr/bin/node check-payments.ts
```

Или используйте встроенную cron задачу в NestJS (проверка истечения подписок каждый час).

## 8. Telegram Bot команды

Пользователь может использовать следующие команды:

- `/start` - Регистрация и главное меню
- `/trial` - Активировать пробный период (24 часа)
- `/buy` - Купить подписку
- `/status` - Просмотр статуса аккаунта
- `/devices` - Управление устройствами
- `/support` - Связаться с поддержкой

## 9. Пример конфига WireGuard

После создания peer, пользователь получает конфиг вида:

```
[Interface]
PrivateKey = CLIENT_PRIVATE_KEY
Address = 10.0.0.2/32
DNS = 1.1.1.1,8.8.8.8

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = 1.2.3.4:51820
AllowedIPs = 0.0.0.0/0,::/0
PresharedKey = PRESHARED_KEY
PersistentKeepalive = 25
```

Этот конфиг можно:
- Импортировать в приложение WireGuard
- Отсканировать через QR-код (бот отправляет QR автоматически)

## 10. Масштабирование: добавление второго сервера

1. Установите WireGuard на втором сервере (используйте скрипт)
2. Используйте другую сеть для второго сервера (например, 10.0.1.0/24)
3. Зарегистрируйте сервер через API
4. Система автоматически будет распределять пользователей между серверами

