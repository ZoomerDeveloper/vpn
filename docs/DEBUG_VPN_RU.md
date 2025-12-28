# Отладка VPN для пользователей из РФ

## Шаг 1: Диагностика на сервере

```bash
cd /opt/vpn-service/scripts

# Общая диагностика
bash diagnose-ru-vpn.sh http://localhost:3000

# С конфигурацией конкретного пользователя (нужен USER_ID)
bash diagnose-ru-vpn.sh http://localhost:3000 USER_ID

# Тестирование конфигурации
bash test-vpn-config.sh http://localhost:3000 USER_ID
```

## Шаг 2: Проверка DNS

```bash
# Проверить DNS в базе данных
sudo -u postgres psql -d vpn_service -c "SELECT id, name, dns FROM vpn_servers;"

# Обновить DNS если нужно
sudo -u postgres psql -d vpn_service -c "UPDATE vpn_servers SET dns = '1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4';"
```

## Шаг 3: Проверка конфигурации пользователя

```bash
# Получить конфигурацию через API
curl http://localhost:3000/vpn/peers/PEER_ID/config

# Проверить что DNS правильный в ответе
```

## Шаг 4: Проверка на стороне пользователя (Android/iOS)

### Android

1. **Проверка подключения:**
   - Откройте WireGuard
   - Проверьте что туннель активен (зеленая точка)

2. **Проверка IP:**
   ```bash
   # Через ADB или терминал
   curl ifconfig.me
   # Должен показать IP VPN сервера, а не ваш реальный IP
   ```

3. **Проверка DNS:**
   ```bash
   nslookup google.com
   # Должен резолвить адрес через DNS из конфигурации
   ```

4. **Просмотр конфигурации:**
   - Откройте WireGuard
   - Нажмите на конфигурацию
   - Проверьте что DNS содержит `1.1.1.1` или `8.8.8.8`

### iOS

1. **Проверка подключения:**
   - Откройте WireGuard
   - Проверьте что туннель активен

2. **Проверка DNS:**
   - Настройки → VPN → WireGuard → DNS
   - Должен быть указан DNS из конфигурации

## Шаг 5: Типичные проблемы и решения

### Проблема 1: DNS не резолвится

**Причина:** DNS запросы блокируются или неправильный DNS в конфигурации

**Решение:**
1. Убедитесь что DNS обновлен на сервере
2. Пересоздайте конфигурацию пользователя
3. Проверьте что DNS в новой конфигурации правильный

### Проблема 2: VPN подключается, но сайты не открываются

**Причина:** DNS запросы идут не через VPN

**Решение:**
1. Проверьте что `AllowedIPs = 0.0.0.0/0,::/0` (весь трафик через VPN)
2. Проверьте что DNS указан в конфигурации
3. Переподключитесь к VPN

### Проблема 3: Конфигурация не импортируется

**Причина:** Неправильный формат конфигурации

**Решение:**
1. Используйте файл `.conf` вместо QR-кода
2. Проверьте что файл содержит правильную структуру:
   ```
   [Interface]
   PrivateKey = ...
   Address = ...
   DNS = ...
   
   [Peer]
   PublicKey = ...
   Endpoint = ...
   AllowedIPs = ...
   ```

### Проблема 4: Handshake не происходит

**Причина:** Peer не добавлен на сервер или неправильный ключ

**Решение:**
1. Проверьте что peer активен в базе данных
2. Проверьте что peer виден на WireGuard сервере: `sudo wg show wg0`
3. Пересоздайте peer через бота

## Шаг 6: Полная диагностика

```bash
# 1. Проверка сервера
bash scripts/diagnose-vpn.sh

# 2. Проверка DNS
bash scripts/check-wireguard.sh

# 3. Проверка конфигурации пользователя
bash scripts/test-vpn-config.sh http://localhost:3000 USER_ID

# 4. Проверка логов
sudo journalctl -u vpn-backend -n 100 --no-pager
sudo journalctl -u wg-quick@wg0 -n 50 --no-pager
```

## Шаг 7: Сброс и пересоздание

Если ничего не помогает:

```bash
# 1. Удалить peer пользователя через API или бота
# 2. Создать новый peer
# 3. Получить новую конфигурацию
# 4. Импортировать на устройство
```

## Полезные команды

```bash
# Проверить активные peer'ы на сервере
sudo wg show wg0

# Проверить маршрутизацию
sudo iptables -t nat -L POSTROUTING -v -n

# Проверить DNS в базе
sudo -u postgres psql -d vpn_service -c "SELECT dns FROM vpn_servers;"

# Получить конфигурацию через API
curl http://localhost:3000/vpn/peers/PEER_ID/config | jq -r '.config'
```

