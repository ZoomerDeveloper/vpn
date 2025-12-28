# Быстрое решение проблемы VPN в РФ

## Симптомы из логов:
- ✅ Handshake активен (7-44 секунды назад)
- ✅ Allowed IPs настроен (10.0.0.34/32)
- ❌ Трафик не проходит (только 404 B received, несколько KiB sent - это только handshake пакеты)
- ❌ Интернет не работает

## Решение (по приоритету):

### 1. Проверить что DNS правильный в конфигурации клиента

Попросите пользователя проверить в WireGuard приложении:
- Открыть конфигурацию
- Проверить строку `DNS = 1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4`
- Если DNS другой или отсутствует → пересоздать конфигурацию

### 2. Пересоздать конфигурацию пользователя

**Через админку:**
1. Найти пользователя
2. Нажать "✕" (деактивация peer)
3. Пользователю создать новое устройство через бота

**Через скрипт:**
```bash
cd /opt/vpn-service/scripts

# 1. Найти USER_ID
bash get-user-id.sh TELEGRAM_ID

# 2. Пересоздать конфигурацию
bash recreate-user-config.sh USER_ID
```

### 3. Проверить и исправить allowed-ips на сервере

Если в логах видно `allowed ips: (none)`, исправить:

```bash
cd /opt/vpn-service/scripts

# Для peer с IP 10.0.0.34
sudo wg set wg0 peer 5qqjkBgqS70lLDQEmsYsctdJfchSUeEdxGHUpnq5UlU= allowed-ips 10.0.0.34/32

# Проверить результат
sudo wg show wg0 | grep -A 10 "5qqjkBgqS70lLDQE"
```

### 4. Проверить маршрутизацию на сервере

```bash
# IP forwarding
sysctl net.ipv4.ip_forward  # Должно быть: net.ipv4.ip_forward = 1

# iptables NAT правила
sudo iptables -t nat -L POSTROUTING -v -n | grep MASQUERADE

# Если нет правил, добавить:
MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)
sudo iptables -t nat -A POSTROUTING -o $MAIN_IF -j MASQUERADE
```

### 5. Проверить DNS на сервере

```bash
# DNS в базе данных
sudo -u postgres psql -d vpn_service -c "SELECT name, dns FROM vpn_servers;"

# Обновить если нужно
cd /opt/vpn-service/scripts
bash update-server-dns.sh http://localhost:3000
```

### 6. Проверить доступность DNS с сервера

```bash
# Проверка что DNS доступен
dig @1.1.1.1 google.com +short
dig @8.8.8.8 google.com +short
```

## Чаще всего проблема в DNS

Если пользователь использует старую конфигурацию без правильного DNS → пересоздать конфигурацию решает проблему.

