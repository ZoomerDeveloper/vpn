# Админ панель VPN сервиса

## Настройка

### 1. Установите токен доступа

Добавьте в `.env` файл:

```env
ADMIN_TOKEN=your_secure_random_token_here
```

Генерируйте безопасный токен:

```bash
# Linux/Mac
openssl rand -hex 32

# Или просто используйте случайную строку
```

### 2. Запустите backend

Админ панель будет доступна по адресу:

```
http://localhost:3000/admin?token=YOUR_ADMIN_TOKEN
```

## Функционал

### Статистика

- Общее количество пользователей
- Активные пользователи (trial + active)
- Всего платежей
- Ожидающие платежи
- Общий доход
- Количество серверов

### Управление пользователями

- Просмотр списка всех пользователей
- Фильтрация по Telegram ID, username, имени
- Просмотр статуса пользователя (active, trial, expired, blocked)
- Просмотр активных VPN peer'ов пользователя
- Сброс trial статуса
- Активация/деактивация VPN peer'ов

### Управление платежами

- Просмотр всех платежей
- Фильтрация по статусу (pending, completed, failed)
- Подтверждение ожидающих платежей
- Просмотр деталей платежа (пользователь, тариф, сумма)

### Управление серверами

- Просмотр списка всех WireGuard серверов
- Просмотр количества активных peer'ов на сервере
- Просмотр DNS настроек серверов
- Статус сервера (активен/неактивен)

## API Endpoints

Все endpoints требуют аутентификации через токен:

```
Authorization: Bearer YOUR_ADMIN_TOKEN
```

Или через query параметр:

```
?token=YOUR_ADMIN_TOKEN
```

### Статистика

```
GET /admin/stats
```

### Пользователи

```
GET /admin/users
GET /admin/users/:id
POST /admin/users/:id/reset-trial
```

### VPN Peers

```
PATCH /admin/vpn/peers/:peerId/activate
PATCH /admin/vpn/peers/:peerId/deactivate
```

### Платежи

```
GET /admin/payments
GET /admin/payments/pending
POST /admin/payments/:id/confirm
```

### Серверы

```
GET /admin/servers
```

## Безопасность

⚠️ **Важно:**

1. Используйте сложный случайный токен для `ADMIN_TOKEN`
2. Не храните токен в публичных репозиториях
3. Используйте HTTPS в продакшене
4. Ограничьте доступ к админ панели по IP (через nginx/firewall)
5. Регулярно меняйте токен

### Рекомендации для продакшена

1. **Nginx reverse proxy с IP whitelist:**

```nginx
location /admin {
    allow YOUR_IP_ADDRESS;
    deny all;
    
    proxy_pass http://localhost:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

2. **Добавить rate limiting:**

```nginx
limit_req_zone $binary_remote_addr zone=admin:10m rate=10r/m;

location /admin {
    limit_req zone=admin burst=5;
    # ...
}
```

3. **Использовать отдельный домен** (например, `admin.yourvpn.com`)

## Примеры использования

### Получить статистику

```bash
curl http://localhost:3000/admin/stats?token=YOUR_ADMIN_TOKEN
```

### Сбросить trial пользователя

```bash
curl -X POST http://localhost:3000/admin/users/USER_ID/reset-trial?token=YOUR_ADMIN_TOKEN
```

### Подтвердить платеж

```bash
curl -X POST http://localhost:3000/admin/payments/PAYMENT_ID/confirm?token=YOUR_ADMIN_TOKEN \
  -H "Content-Type: application/json" \
  -d '{"transactionHash": "optional_hash"}'
```

### Деактивировать peer

```bash
curl -X PATCH http://localhost:3000/admin/vpn/peers/PEER_ID/deactivate?token=YOUR_ADMIN_TOKEN
```

