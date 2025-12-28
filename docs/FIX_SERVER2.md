# Исправление проблем с server2

## Проблема

Устройство подключено к server2, но ничего не работает (нет интернета через VPN).

## Быстрая диагностика

```bash
cd /opt/vpn-service

# Проверить server2
bash scripts/check-server2-connection.sh [USER_ID или TELEGRAM_ID]
```

## Основные причины и решения

### 1. MTU не установлен на server2

**Проблема:** Server2 не имеет `MTU = 1280` в конфиге, что критично для работы в РФ.

**Решение:**

```bash
# На server2
ssh root@SERVER2_IP
cd /opt/vpn-service
bash scripts/fix-server-mtu.sh
```

Или вручную:

```bash
ssh root@SERVER2_IP
nano /etc/wireguard/wg0.conf

# Добавить в секцию [Interface]:
MTU = 1280

# Перезапустить
systemctl restart wg-quick@wg0
```

**Проверка:**

```bash
ssh root@SERVER2_IP 'grep MTU /etc/wireguard/wg0.conf'
# Должно быть: MTU = 1280
```

### 2. DNS не настроен правильно

**Проблема:** DNS не установлен или установлен неправильный.

**Решение:**

```bash
# Обновить DNS через API
SERVER2_ID=$(curl -s http://localhost:3000/wireguard/servers | jq -r '.[] | select(.name | contains("server2")) | .id')

curl -X PATCH http://localhost:3000/wireguard/servers/$SERVER2_ID \
  -H "Content-Type: application/json" \
  -d '{"dns": "1.1.1.1"}'
```

**После обновления DNS нужно пересоздать конфиги всех пользователей на server2:**

```bash
# Получить список пользователей на server2
USERS=$(curl -s http://localhost:3000/admin/users | jq -r '.[] | select(.peers[].server.name | contains("server2")) | .id')

# Для каждого пользователя
for USER_ID in $USERS; do
    bash scripts/recreate-user-config.sh $USER_ID
done
```

### 3. NAT не работает

**Проблема:** NAT правила не настроены или потеряны.

**Решение:**

```bash
ssh root@SERVER2_IP

# Определить основной интерфейс
MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)
echo "Основной интерфейс: $MAIN_IF"

# Определить сеть server2
NETWORK=$(grep Address /etc/wireguard/wg0.conf | head -1 | awk '{print $3}' | cut -d'/' -f1 | sed 's/\.[0-9]*$/.0/24')
echo "Сеть: $NETWORK"

# Добавить NAT правило
iptables -t nat -A POSTROUTING -s $NETWORK -o $MAIN_IF -j MASQUERADE

# Сохранить правила
apt install -y iptables-persistent
netfilter-persistent save
```

**Проверка:**

```bash
ssh root@SERVER2_IP 'iptables -t nat -L POSTROUTING -n | grep MASQUERADE'
```

### 4. WireGuard не запущен

**Проблема:** Сервис WireGuard не запущен или упал.

**Решение:**

```bash
ssh root@SERVER2_IP
systemctl status wg-quick@wg0
systemctl restart wg-quick@wg0
systemctl enable wg-quick@wg0
```

### 5. Порт блокируется

**Проблема:** Порт server2 блокируется DPI.

**Решение:** Изменить порт на 443/UDP:

```bash
# На server2
ssh root@SERVER2_IP
nano /etc/wireguard/wg0.conf

# Изменить:
ListenPort = 443

# Перезапустить
systemctl restart wg-quick@wg0

# Обновить в базе данных
SERVER2_ID=$(curl -s http://localhost:3000/wireguard/servers | jq -r '.[] | select(.name | contains("server2")) | .id')

curl -X PATCH http://localhost:3000/wireguard/servers/$SERVER2_ID \
  -H "Content-Type: application/json" \
  -d '{"port": 443}'

# Пересоздать конфиги пользователей
bash scripts/recreate-user-config.sh USER_ID
```

### 6. Пользователь использует старый конфиг

**Проблема:** Конфиг был создан до применения MTU и правильных настроек.

**Решение:** Пересоздать конфиг:

```bash
# Найти USER_ID
USER_ID=$(curl -s http://localhost:3000/users | jq -r '.[] | select(.telegramId == "TELEGRAM_ID") | .id')

# Пересоздать конфиг
bash scripts/recreate-user-config.sh $USER_ID

# Пользователю нужно:
# 1. Удалить старый peer в приложении WireGuard
# 2. Добавить новый конфиг (через QR-код или вручную)
```

## Полная проверка server2

```bash
# 1. Подключиться к server2
ssh root@SERVER2_IP

# 2. Проверить конфиг
cat /etc/wireguard/wg0.conf
# Должно быть:
# - MTU = 1280
# - ListenPort = 443 (или другой порт)
# - PostUp с NAT правилами

# 3. Проверить статус
systemctl status wg-quick@wg0
wg show wg0

# 4. Проверить NAT
iptables -t nat -L POSTROUTING -n | grep MASQUERADE

# 5. Проверить IP forwarding
sysctl net.ipv4.ip_forward
# Должно быть: net.ipv4.ip_forward = 1

# 6. Проверить порт
netstat -ulnp | grep :443
# Или если другой порт:
netstat -ulnp | grep wg-quick
```

## Автоматическое исправление (если server2 настроен через скрипт)

Если server2 был настроен через `add-new-vpn-server.sh`, проверить что все шаги выполнены:

```bash
# На server2
ssh root@SERVER2_IP
cd /opt/vpn-service

# 1. Проверить MTU
bash scripts/fix-server-mtu.sh

# 2. Проверить что всё работает
systemctl status wg-quick@wg0
wg show wg0
```

## Миграция пользователя на другой сервер

Если server2 не работает, можно временно мигрировать пользователя на server1:

**Через админку:**
1. Открыть админку: `http://API_IP:3000/admin?token=TOKEN`
2. Найти пользователя
3. Нажать "Мигрировать" рядом с peer
4. Выбрать server1

**Через API:**

```bash
# Получить ID peer
PEER_ID=$(curl -s http://localhost:3000/vpn/users/USER_ID/peers | jq -r '.[] | select(.serverId == "SERVER2_ID") | .id')

# Получить ID server1
SERVER1_ID=$(curl -s http://localhost:3000/wireguard/servers | jq -r '.[] | select(.name | contains("server1")) | .id')

# Мигрировать
curl -X POST http://localhost:3000/admin/vpn/peers/$PEER_ID/migrate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -d "{\"serverId\": \"$SERVER1_ID\"}"
```

## После исправления

1. ✅ Пересоздать конфиг пользователя
2. ✅ Пользователь должен удалить старый peer и добавить новый
3. ✅ Проверить что работает: `ping 1.1.1.1` через VPN

