#!/bin/bash

# Скрипт для тестирования конфигурации VPN
# Использование: bash test-vpn-config.sh [API_URL] [USER_ID]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_URL="${1:-http://localhost:3000}"
USER_ID="${2}"

if [ -z "$USER_ID" ]; then
    echo -e "${YELLOW}Использование: bash test-vpn-config.sh [API_URL] USER_ID${NC}"
    echo "Пример: bash test-vpn-config.sh http://localhost:3000 47c0b409-4729-4d5c-b51d-8b4d25b54994"
    exit 1
fi

echo -e "${BLUE}🧪 Тестирование конфигурации VPN...${NC}"
echo ""

# Получаем peer'ы пользователя
echo -e "${YELLOW}Получаю peer'ы пользователя...${NC}"
PEERS=$(curl -s "${API_URL}/vpn/users/${USER_ID}/peers")

if echo "$PEERS" | grep -q "\[\]"; then
    echo -e "${RED}❌ У пользователя нет активных peer'ов${NC}"
    exit 1
fi

PEER_ID=$(echo "$PEERS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data[0]['id'] if isinstance(data, list) and len(data) > 0 else '')" 2>/dev/null)

if [ -z "$PEER_ID" ]; then
    PEER_ID=$(echo "$PEERS" | grep -oP '"id"\s*:\s*"\K[^"]+' | head -1)
fi

if [ -z "$PEER_ID" ]; then
    echo -e "${RED}❌ Не удалось получить ID peer'а${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Найден peer: ${PEER_ID:0:8}...${NC}"

# Получаем конфигурацию
echo -e "${YELLOW}Получаю конфигурацию...${NC}"
CONFIG_RESPONSE=$(curl -s "${API_URL}/vpn/peers/${PEER_ID}/config")

# Извлекаем конфигурацию из JSON
CONFIG=$(echo "$CONFIG_RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('config', ''))" 2>/dev/null)

if [ -z "$CONFIG" ]; then
    # Пробуем другой способ
    CONFIG=$(echo "$CONFIG_RESPONSE" | grep -o '"config":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g')
fi

if [ -z "$CONFIG" ]; then
    echo -e "${RED}❌ Не удалось получить конфигурацию${NC}"
    echo "Ответ API:"
    echo "$CONFIG_RESPONSE" | head -20
    exit 1
fi

echo -e "${GREEN}✓ Конфигурация получена${NC}"
echo ""

# Сохраняем во временный файл
TEMP_CONFIG="/tmp/test-vpn-config-$$.conf"
echo "$CONFIG" > "$TEMP_CONFIG"

echo -e "${BLUE}📄 Содержимое конфигурации:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$TEMP_CONFIG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Проверяем структуру конфигурации
echo -e "${YELLOW}Проверка структуры конфигурации:${NC}"

HAS_INTERFACE=$(grep -c "^\[Interface\]" "$TEMP_CONFIG" || echo "0")
HAS_PEER=$(grep -c "^\[Peer\]" "$TEMP_CONFIG" || echo "0")
HAS_PRIVATE_KEY=$(grep -c "^PrivateKey = " "$TEMP_CONFIG" || echo "0")
HAS_PUBLIC_KEY=$(grep -c "^PublicKey = " "$TEMP_CONFIG" || echo "0")
HAS_ADDRESS=$(grep -c "^Address = " "$TEMP_CONFIG" || echo "0")
HAS_DNS=$(grep -c "^DNS = " "$TEMP_CONFIG" || echo "0")
HAS_ENDPOINT=$(grep -c "^Endpoint = " "$TEMP_CONFIG" || echo "0")
HAS_ALLOWED_IPS=$(grep -c "^AllowedIPs = " "$TEMP_CONFIG" || echo "0")

echo "  [Interface]: $([ $HAS_INTERFACE -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  PrivateKey: $([ $HAS_PRIVATE_KEY -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  Address: $([ $HAS_ADDRESS -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  DNS: $([ $HAS_DNS -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  [Peer]: $([ $HAS_PEER -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  PublicKey: $([ $HAS_PUBLIC_KEY -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  Endpoint: $([ $HAS_ENDPOINT -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  AllowedIPs: $([ $HAS_ALLOWED_IPS -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"

# Проверяем DNS
if [ $HAS_DNS -gt 0 ]; then
    DNS_VALUE=$(grep "^DNS = " "$TEMP_CONFIG" | cut -d'=' -f2 | xargs)
    echo ""
    echo -e "${BLUE}DNS в конфигурации: $DNS_VALUE${NC}"
    
    if echo "$DNS_VALUE" | grep -q "1.1.1.1\|8.8.8.8"; then
        echo -e "${GREEN}✓ DNS содержит надежные серверы${NC}"
    else
        echo -e "${RED}❌ DNS не содержит надежные серверы!${NC}"
        echo -e "${YELLOW}  Нужно обновить DNS и пересоздать конфигурацию${NC}"
    fi
fi

# Проверяем формат Address
if [ $HAS_ADDRESS -gt 0 ]; then
    ADDRESS_VALUE=$(grep "^Address = " "$TEMP_CONFIG" | cut -d'=' -f2 | xargs)
    echo ""
    echo -e "${BLUE}Address в конфигурации: $ADDRESS_VALUE${NC}"
    
    if echo "$ADDRESS_VALUE" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$"; then
        echo -e "${GREEN}✓ Формат Address правильный${NC}"
    else
        echo -e "${RED}❌ Формат Address неправильный!${NC}"
    fi
fi

# Удаляем временный файл
rm -f "$TEMP_CONFIG"

echo ""
echo -e "${GREEN}Тестирование завершено!${NC}"

