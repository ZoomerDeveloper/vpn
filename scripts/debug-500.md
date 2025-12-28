# Отладка ошибки 500

## Проверка статуса сервисов

```bash
# Проверьте что Backend запущен
sudo systemctl status vpn-backend

# Или если запущен вручную, проверьте процесс
ps aux | grep node

# Проверьте логи Backend
sudo journalctl -u vpn-backend -n 50 --no-pager
# или если запущен вручную
# смотрите вывод в терминале где запущен backend
```

## Проверка подключения к API

```bash
# Проверьте что API отвечает
curl http://localhost:3000/health

# Проверьте что API доступен для бота
curl http://localhost:3000/tariffs
```

## Типичные причины ошибки 500 при /trial:

1. **Backend не запущен**
   - Решение: Запустите backend

2. **Проблема с подключением к БД**
   - Проверьте .env файл (DB_PASSWORD, DB_USERNAME)
   - Проверьте что PostgreSQL запущен: `sudo systemctl status postgresql`

3. **Нет WireGuard серверов в БД**
   - При создании peer система ищет доступный сервер
   - Если серверов нет - будет ошибка
   - Решение: Зарегистрируйте WireGuard сервер через API

4. **Проблема с WireGuard на сервере**
   - WireGuard не установлен или не настроен
   - Решение: Настройте WireGuard сервер

## Быстрая проверка:

```bash
# 1. Проверьте что Backend запущен
curl http://localhost:3000/health

# 2. Проверьте логи
sudo journalctl -u vpn-backend -f

# 3. Проверьте что есть WireGuard серверы
curl http://localhost:3000/wireguard/servers
```

## Если Backend не запущен:

```bash
# Запустите вручную для отладки
cd /opt/vpn-service/backend
npm run start:prod

# Смотрите ошибки в консоли
```

