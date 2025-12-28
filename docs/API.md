# API Документация

Базовый URL: `http://your-domain:3000`

## Users API

### Получить всех пользователей
```
GET /users
```

### Получить пользователя по ID
```
GET /users/:id
```

### Найти пользователя по Telegram ID
```
GET /users/telegram/:telegramId

Response:
{
  "id": "uuid",
  "telegramId": "123456789",
  "username": "user123",
  "status": "active",
  "tariffId": "uuid",
  "expireAt": "2024-12-31T23:59:59.000Z",
  "trialUsed": false,
  ...
}
```

### Создать пользователя
```
POST /users
Body:
{
  "telegramId": "123456789",
  "username": "user123",
  "firstName": "Иван",
  "lastName": "Иванов"
}
```

### Активировать trial
```
POST /users/:id/trial
Body:
{
  "hours": 24  // опционально, по умолчанию 24
}
```

## VPN API

### Создать VPN peer
```
POST /vpn/users/:userId/peers

Response:
{
  "peer": {
    "id": "uuid",
    "publicKey": "...",
    "allocatedIp": "10.0.0.2/32",
    "isActive": true,
    ...
  },
  "config": "[Interface]\nPrivateKey = ...\n..."
}
```

### Получить список peers пользователя
```
GET /vpn/users/:userId/peers

Response:
[
  {
    "id": "uuid",
    "publicKey": "...",
    "allocatedIp": "10.0.0.2/32",
    "isActive": true,
    "server": { ... }
  }
]
```

### Получить конфиг peer
```
GET /vpn/peers/:peerId/config

Response:
{
  "config": "[Interface]\nPrivateKey = ...\n..."
}
```

### Деактивировать peer
```
PATCH /vpn/peers/:peerId/deactivate
Body:
{
  "userId": "uuid"  // опционально, для проверки прав
}
```

### Активировать peer
```
PATCH /vpn/peers/:peerId/activate
Body:
{
  "userId": "uuid"
}
```

## Payments API

### Создать платеж
```
POST /payments
Body:
{
  "userId": "uuid",
  "tariffId": "uuid",
  "provider": "usdt_trc20"  // опционально
}

Response:
{
  "id": "uuid",
  "amount": 299,
  "currency": "RUB",
  "status": "pending",
  ...
}
```

### Получить адрес для оплаты
```
POST /payments/:id/address

Response:
{
  "address": "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
  "amount": 10.5
}
```

### Подтвердить платеж
```
POST /payments/:id/confirm
Body:
{
  "transactionHash": "abc123..."  // опционально
}

Response:
{
  "id": "uuid",
  "status": "completed",
  ...
}
```

### Получить ожидающие платежи
```
GET /payments/pending

Response:
[
  {
    "id": "uuid",
    "status": "pending",
    "user": { ... },
    "tariff": { ... }
  }
]
```

### Получить платежи пользователя
```
GET /payments/user/:userId
```

## Tariffs API

### Получить все тарифы
```
GET /tariffs

Response:
[
  {
    "id": "uuid",
    "name": "1 месяц",
    "description": "...",
    "price": 299,
    "currency": "RUB",
    "durationDays": 30,
    "devicesLimit": 1
  }
]
```

### Получить тариф по ID
```
GET /tariffs/:id
```

### Создать тариф (admin)
```
POST /tariffs
Body:
{
  "name": "1 месяц",
  "description": "Базовый тариф",
  "price": 299,
  "currency": "RUB",
  "durationDays": 30,
  "devicesLimit": 1
}
```

### Обновить тариф (admin)
```
PATCH /tariffs/:id
Body:
{
  "price": 249,
  ...
}
```

## WireGuard API

### Получить все серверы
```
GET /wireguard/servers
```

### Добавить сервер
```
POST /wireguard/servers
Body:
{
  "name": "server1",
  "host": "vpn.example.com",
  "port": 51820,
  "publicIp": "1.2.3.4",
  "privateIp": "10.0.0.1",
  "endpoint": "1.2.3.4",
  "network": "10.0.0.0/24",
  "dns": "1.1.1.1,8.8.8.8",
  "publicKey": "...",
  "privateKey": "..."  // опционально
}
```

### Добавить peer на сервер
```
POST /wireguard/servers/:serverId/peers
Body:
{
  "publicKey": "...",
  "allocatedIp": "10.0.0.2/32",
  "presharedKey": "..."  // опционально
}
```

### Удалить peer с сервера
```
DELETE /wireguard/servers/:serverId/peers/:publicKey
```

## Health Check

### Проверка здоровья сервиса
```
GET /health

Response:
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

