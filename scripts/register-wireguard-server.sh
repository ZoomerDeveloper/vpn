#!/bin/bash

# Скрипт для автоматической регистрации WireGuard сервера в Backend API
# Использование: ./register-wireguard-server.sh [API_URL] [SERVER_NAME]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

API_URL="${1:-http://localhost:3000}"
SERVER_NAME="${2:-server1}"
WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_CONFIG_PATH="${WG_CONFIG_PATH:-/etc/wireguard}"

echo -e "${GREEN}🔧 Регистрация WireGuard сервера в Backend API...${NC}"

# Проверяем что WireGuard установлен
if ! command -v wg &> /dev/null; then
    echo -e "${RED}❌ WireGuard не установлен. Установите его сначала.${NC}"
    exit 1
fi

# Получаем public key сервера
SERVER_PUBLIC_KEY_FILE="${WG_CONFIG_PATH}/server_public.key"
SERVER_PRIVATE_KEY_FILE="${WG_CONFIG_PATH}/server_private.key"

if [ ! -f "$SERVER_PUBLIC_KEY_FILE" ]; then
    echo -e "${YELLOW}⚠️  Public key файл не найден. Генерирую ключи...${NC}"
    
    if [ ! -f "$SERVER_PRIVATE_KEY_FILE" ]; then
        wg genkey | tee "$SERVER_PRIVATE_KEY_FILE" | wg pubkey > "$SERVER_PUBLIC_KEY_FILE"
        chmod 600 "$SERVER_PRIVATE_KEY_FILE"
        chmod 644 "$SERVER_PUBLIC_KEY_FILE"
        echo -e "${GREEN}✓ Ключи сгенерированы${NC}"
    else
        wg pubkey < "$SERVER_PRIVATE_KEY_FILE" > "$SERVER_PUBLIC_KEY_FILE"
        chmod 644 "$SERVER_PUBLIC_KEY_FILE"
        echo -e "${GREEN}✓ Public key создан из private key${NC}"
    fi
fi

SERVER_PUBLIC_KEY=$(cat "$SERVER_PUBLIC_KEY_FILE")
SERVER_PRIVATE_KEY=$(cat "$SERVER_PRIVATE_KEY_FILE")

# Получаем IP адреса
PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || hostname -I | awk '{print $1}')
PRIVATE_IP=$(hostname -I | awk '{print $1}')

# Пытаемся получить endpoint из конфига WireGuard, если он существует
WG_CONFIG="${WG_CONFIG_PATH}/${WG_INTERFACE}.conf"
if [ -f "$WG_CONFIG" ]; then
    LISTEN_PORT=$(grep "^ListenPort" "$WG_CONFIG" | awk '{print $3}' || echo "51820")
    # Пытаемся найти Address из конфига
    WG_ADDRESS=$(grep "^Address" "$WG_CONFIG" | head -1 | awk '{print $3}' | cut -d'/' -f1 || echo "")
    if [ ! -z "$WG_ADDRESS" ]; then
        PRIVATE_IP="$WG_ADDRESS"
    fi
else
    LISTEN_PORT="51820"
fi

# Определяем network (используем подсеть из PRIVATE_IP)
if [[ "$PRIVATE_IP" =~ ^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\. ]]; then
    NETWORK_BASE="${BASH_REMATCH[1]}"
    NETWORK="${NETWORK_BASE}.0/24"
else
    NETWORK="10.0.0.0/24"
fi

# Пытаемся определить endpoint (публичный IP или из конфига)
ENDPOINT="${PUBLIC_IP}"

# DNS по умолчанию (оптимизировано для РФ)
DNS="1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4"

echo -e "${GREEN}📊 Информация о сервере:${NC}"
echo "  Имя: $SERVER_NAME"
echo "  Public IP: $PUBLIC_IP"
echo "  Private IP: $PRIVATE_IP"
echo "  Endpoint: $ENDPOINT"
echo "  Port: $LISTEN_PORT"
echo "  Network: $NETWORK"
echo "  Public Key: ${SERVER_PUBLIC_KEY:0:20}..."

# Проверяем доступность API
echo -e "${YELLOW}🔍 Проверяю доступность API...${NC}"
if ! curl -s "${API_URL}/health" > /dev/null 2>&1; then
    echo -e "${RED}❌ API недоступен по адресу ${API_URL}${NC}"
    echo -e "${YELLOW}Убедитесь что Backend запущен или укажите правильный URL:${NC}"
    echo "  ./register-wireguard-server.sh http://your-api-url:3000 server1"
    exit 1
fi

echo -e "${GREEN}✓ API доступен${NC}"

# Регистрируем сервер через API
echo -e "${YELLOW}📤 Регистрирую сервер в Backend...${NC}"

RESPONSE=$(curl -s -X POST "${API_URL}/wireguard/servers" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$SERVER_NAME\",
    \"host\": \"$PUBLIC_IP\",
    \"port\": $LISTEN_PORT,
    \"publicIp\": \"$PUBLIC_IP\",
    \"privateIp\": \"$PRIVATE_IP\",
    \"endpoint\": \"$ENDPOINT\",
    \"network\": \"$NETWORK\",
    \"dns\": \"$DNS\",
    \"publicKey\": \"$SERVER_PUBLIC_KEY\",
    \"privateKey\": \"$SERVER_PRIVATE_KEY\"
  }")

# Проверяем ответ
if echo "$RESPONSE" | grep -q "\"id\""; then
    SERVER_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "${GREEN}✅ Сервер успешно зарегистрирован!${NC}"
    echo -e "${GREEN}Server ID: ${SERVER_ID}${NC}"
    echo ""
    echo -e "${GREEN}Теперь можно использовать этот сервер для создания VPN peers.${NC}"
else
    # Проверяем ошибки
    if echo "$RESPONSE" | grep -q "already exists"; then
        echo -e "${YELLOW}⚠️  Сервер с таким именем уже существует${NC}"
        echo -e "${YELLOW}Используйте другое имя или удалите существующий сервер${NC}"
    else
        echo -e "${RED}❌ Ошибка при регистрации сервера:${NC}"
        echo "$RESPONSE" | head -20
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}🎉 Готово!${NC}"

