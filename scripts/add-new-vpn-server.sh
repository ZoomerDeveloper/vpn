#!/bin/bash

# Скрипт для добавления нового WireGuard сервера в систему
# Использование: bash add-new-vpn-server.sh SERVER_IP [SERVER_NAME]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SERVER_IP="${1}"
SERVER_NAME="${2:-server2}"
API_URL="${API_URL:-http://localhost:3000}"
SERVER_USER="${SERVER_USER:-root}"

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}❌ Ошибка: Не указан IP адрес сервера${NC}"
    echo -e "${YELLOW}Использование: bash add-new-vpn-server.sh SERVER_IP [SERVER_NAME]${NC}"
    echo "Пример: bash add-new-vpn-server.sh 192.168.1.100 server2"
    exit 1
fi

echo -e "${BLUE}🔧 Добавление нового WireGuard сервера...${NC}"
echo -e "${CYAN}IP: $SERVER_IP${NC}"
echo -e "${CYAN}Имя: $SERVER_NAME${NC}"
echo ""

# ШАГ 1: Настройка WireGuard на новом сервере
echo -e "${YELLOW}ШАГ 1: Настройка WireGuard на сервере $SERVER_IP...${NC}"

if [ -z "$SSHPASS" ]; then
    echo -e "${YELLOW}Будет запрошен пароль для SSH${NC}"
    ssh "$SERVER_USER@$SERVER_IP" "bash -s" < scripts/setup-wireguard.sh
else
    sshpass -e ssh "$SERVER_USER@$SERVER_IP" "bash -s" < scripts/setup-wireguard.sh
fi

# ШАГ 2: Установка MTU = 1280 на новом сервере
echo ""
echo -e "${YELLOW}ШАГ 2: Установка MTU = 1280 на новом сервере...${NC}"

if [ -z "$SSHPASS" ]; then
    ssh "$SERVER_USER@$SERVER_IP" "bash -s" <<'EOF'
WG_CONFIG="/etc/wireguard/wg0.conf"
MTU_VALUE="1280"

# Проверяем что файл существует
if [ ! -f "$WG_CONFIG" ]; then
    echo "❌ Файл конфигурации не найден: $WG_CONFIG"
    exit 1
fi

# Делаем бэкап
BACKUP_FILE="${WG_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$WG_CONFIG" "$BACKUP_FILE"
echo "✓ Бэкап создан: $BACKUP_FILE"

# Проверяем есть ли уже MTU
if grep -q "^MTU" "$WG_CONFIG"; then
    echo "⚠️  MTU уже задан, обновляю..."
    sed -i "s/^MTU = .*/MTU = ${MTU_VALUE}/" "$WG_CONFIG"
else
    echo "Добавляю MTU = ${MTU_VALUE}..."
    if grep -q "^PrivateKey" "$WG_CONFIG"; then
        sed -i "/^PrivateKey/a MTU = ${MTU_VALUE}" "$WG_CONFIG"
    elif grep -q "^ListenPort" "$WG_CONFIG"; then
        sed -i "/^ListenPort/a MTU = ${MTU_VALUE}" "$WG_CONFIG"
    fi
fi

echo "✓ MTU добавлен"

# Перезапускаем WireGuard
systemctl restart wg-quick@wg0
sleep 2

if systemctl is-active --quiet wg-quick@wg0; then
    echo "✓ WireGuard перезапущен"
    ip link show wg0 | grep -i mtu
else
    echo "❌ Ошибка при перезапуске WireGuard"
    exit 1
fi
EOF
else
    sshpass -e ssh "$SERVER_USER@$SERVER_IP" "bash -s" <<'EOF'
WG_CONFIG="/etc/wireguard/wg0.conf"
MTU_VALUE="1280"

if [ ! -f "$WG_CONFIG" ]; then
    echo "❌ Файл конфигурации не найден: $WG_CONFIG"
    exit 1
fi

BACKUP_FILE="${WG_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$WG_CONFIG" "$BACKUP_FILE"
echo "✓ Бэкап создан"

if grep -q "^MTU" "$WG_CONFIG"; then
    sed -i "s/^MTU = .*/MTU = ${MTU_VALUE}/" "$WG_CONFIG"
else
    if grep -q "^PrivateKey" "$WG_CONFIG"; then
        sed -i "/^PrivateKey/a MTU = ${MTU_VALUE}" "$WG_CONFIG"
    elif grep -q "^ListenPort" "$WG_CONFIG"; then
        sed -i "/^ListenPort/a MTU = ${MTU_VALUE}" "$WG_CONFIG"
    fi
fi

systemctl restart wg-quick@wg0
sleep 2

if systemctl is-active --quiet wg-quick@wg0; then
    echo "✓ WireGuard перезапущен с MTU = 1280"
    ip link show wg0 | grep -i mtu
else
    echo "❌ Ошибка при перезапуске WireGuard"
    exit 1
fi
EOF
fi

# ШАГ 3: Получаем данные сервера
echo ""
echo -e "${YELLOW}ШАГ 3: Получение данных сервера...${NC}"

if [ -z "$SSHPASS" ]; then
    SERVER_DATA=$(ssh "$SERVER_USER@$SERVER_IP" "cat /etc/wireguard/server_public.key /etc/wireguard/server_private.key 2>/dev/null && wg show wg0 listen-port 2>/dev/null | awk '{print \$3}' && curl -s ifconfig.me")
else
    SERVER_DATA=$(sshpass -e ssh "$SERVER_USER@$SERVER_IP" "cat /etc/wireguard/server_public.key /etc/wireguard/server_private.key 2>/dev/null && wg show wg0 listen-port 2>/dev/null | awk '{print \$3}' && curl -s ifconfig.me")
fi

PUBLIC_KEY=$(echo "$SERVER_DATA" | head -1)
PRIVATE_KEY=$(echo "$SERVER_DATA" | head -2 | tail -1)
LISTEN_PORT=$(echo "$SERVER_DATA" | head -3 | tail -1)
PUBLIC_IP_SERVER=$(echo "$SERVER_DATA" | tail -1)

# Проверяем что данные получены
if [ -z "$PUBLIC_KEY" ] || [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ Не удалось получить ключи сервера${NC}"
    echo -e "${YELLOW}Пожалуйста, получите ключи вручную:${NC}"
    echo "  ssh $SERVER_USER@$SERVER_IP 'cat /etc/wireguard/server_public.key'"
    echo "  ssh $SERVER_USER@$SERVER_IP 'cat /etc/wireguard/server_private.key'"
    exit 1
fi

if [ -z "$LISTEN_PORT" ]; then
    LISTEN_PORT="443"
    echo -e "${YELLOW}⚠️  Порт не определен, используем 443${NC}"
fi

if [ -z "$PUBLIC_IP_SERVER" ]; then
    PUBLIC_IP_SERVER="$SERVER_IP"
    echo -e "${YELLOW}⚠️  Публичный IP не определен, используем $SERVER_IP${NC}"
fi

echo -e "${GREEN}✓ Данные получены:${NC}"
echo "  Public Key: ${PUBLIC_KEY:0:20}..."
echo "  Listen Port: $LISTEN_PORT"
echo "  Public IP: $PUBLIC_IP_SERVER"

# ШАГ 4: Регистрируем сервер в backend
echo ""
echo -e "${YELLOW}ШАГ 4: Регистрация сервера в backend...${NC}"

# Определяем сеть (обычно 10.0.0.0/24 для первого сервера, можно использовать другую для второго)
NETWORK="10.0.0.0/24"
PRIVATE_IP="10.0.0.1"

# Формируем JSON для регистрации
REGISTER_JSON=$(cat <<EOF
{
  "name": "$SERVER_NAME",
  "host": "$PUBLIC_IP_SERVER",
  "port": $LISTEN_PORT,
  "publicIp": "$PUBLIC_IP_SERVER",
  "privateIp": "$PRIVATE_IP",
  "endpoint": "$PUBLIC_IP_SERVER",
  "network": "$NETWORK",
  "dns": "1.1.1.1",
  "publicKey": "$PUBLIC_KEY",
  "privateKey": "$PRIVATE_KEY"
}
EOF
)

echo -e "${CYAN}Отправка запроса в backend...${NC}"
RESPONSE=$(curl -s -X POST "${API_URL}/wireguard/servers" \
    -H "Content-Type: application/json" \
    -d "$REGISTER_JSON")

if echo "$RESPONSE" | grep -q "\"id\""; then
    SERVER_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['id'])" 2>/dev/null || echo "")
    echo -e "${GREEN}✅ Сервер успешно зарегистрирован!${NC}"
    echo -e "${GREEN}Server ID: ${SERVER_ID:0:8}...${NC}"
else
    echo -e "${RED}❌ Ошибка при регистрации сервера:${NC}"
    echo "$RESPONSE" | head -20
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Новый сервер успешно добавлен!${NC}"
echo ""
echo -e "${CYAN}Информация о сервере:${NC}"
echo "  Имя: $SERVER_NAME"
echo "  IP: $PUBLIC_IP_SERVER"
echo "  Порт: $LISTEN_PORT"
echo "  Network: $NETWORK"
echo "  DNS: 1.1.1.1"
echo "  MTU: 1280"
echo ""
echo -e "${YELLOW}Следующие шаги:${NC}"
echo "  1. Проверьте что сервер появился в админке"
echo "  2. Новые пользователи будут автоматически распределяться между серверами"
echo "  3. Для миграции существующих пользователей используйте админку (кнопка 'Мигрировать')"

