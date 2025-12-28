#!/bin/bash

# Скрипт для пересоздания конфигурации VPN для пользователя
# Использование: bash recreate-user-config.sh USER_ID

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_URL="${API_URL:-http://localhost:3000}"
USER_ID="$1"

if [ -z "$USER_ID" ]; then
    echo -e "${YELLOW}Использование: bash recreate-user-config.sh USER_ID${NC}"
    echo "Пример: bash recreate-user-config.sh 316c99eb-26e7-410d-8e0d-8e568b0c8ef3"
    exit 1
fi

echo -e "${BLUE}🔄 Пересоздание конфигурации VPN...${NC}"
echo ""

# 1. Удаляем все активные peer'ы пользователя
echo -e "${YELLOW}1. Удаление существующих peer'ов...${NC}"
PEERS=$(curl -s "${API_URL}/vpn/users/${USER_ID}/peers")

if command -v python3 > /dev/null 2>&1; then
    PEER_IDS=$(echo "$PEERS" | python3 -c "
import sys, json
try:
    peers = json.load(sys.stdin)
    if isinstance(peers, list):
        for p in peers:
            if p.get('isActive'):
                print(p['id'])
except:
    pass
" 2>/dev/null)
else
    # Простой парсинг через grep
    PEER_IDS=$(echo "$PEERS" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
fi

if [ -n "$PEER_IDS" ]; then
    for PEER_ID in $PEER_IDS; do
        echo -e "  Удаляем peer: ${PEER_ID:0:8}..."
        curl -s -X PATCH "${API_URL}/vpn/peers/${PEER_ID}/deactivate" \
            -H "Content-Type: application/json" \
            -d "{\"userId\": \"${USER_ID}\"}" > /dev/null 2>&1
    done
    echo -e "${GREEN}✓ Peer'ы удалены${NC}"
else
    echo -e "${YELLOW}⚠️  Активных peer'ов не найдено${NC}"
fi

echo ""

# 2. Создаем новый peer
echo -e "${YELLOW}2. Создание нового peer'а...${NC}"
NEW_PEER_RESPONSE=$(curl -s -X POST "${API_URL}/vpn/users/${USER_ID}/peers" \
    -H "Content-Type: application/json")

if [ -z "$NEW_PEER_RESPONSE" ]; then
    echo -e "${RED}❌ Ошибка при создании peer'а${NC}"
    exit 1
fi

# Извлекаем peer ID и конфигурацию
if command -v python3 > /dev/null 2>&1; then
    NEW_PEER_ID=$(echo "$NEW_PEER_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('peer', {}).get('id', ''))
except:
    pass
" 2>/dev/null)
    
    CONFIG=$(echo "$NEW_PEER_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('config', ''))
except:
    pass
" 2>/dev/null)
else
    NEW_PEER_ID=$(echo "$NEW_PEER_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    CONFIG=$(echo "$NEW_PEER_RESPONSE" | grep -o '"config":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g')
fi

if [ -z "$NEW_PEER_ID" ]; then
    echo -e "${RED}❌ Не удалось создать peer${NC}"
    echo "Ответ API:"
    echo "$NEW_PEER_RESPONSE" | head -20
    exit 1
fi

echo -e "${GREEN}✓ Новый peer создан: ${NEW_PEER_ID:0:8}...${NC}"
echo ""

# 3. Показываем конфигурацию
echo -e "${BLUE}3. Новая конфигурация:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -n "$CONFIG" ]; then
    echo "$CONFIG"
else
    # Получаем конфигурацию отдельно
    CONFIG_RESPONSE=$(curl -s "${API_URL}/vpn/peers/${NEW_PEER_ID}/config")
    CONFIG=$(echo "$CONFIG_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('config', ''))
except:
    pass
" 2>/dev/null || echo "$CONFIG_RESPONSE" | grep -o '"config":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g')
    echo "$CONFIG"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 4. Проверяем DNS в конфигурации
if echo "$CONFIG" | grep -q "DNS = "; then
    DNS_VALUE=$(echo "$CONFIG" | grep "^DNS = " | cut -d'=' -f2 | xargs)
    echo -e "${BLUE}DNS в конфигурации:${NC} $DNS_VALUE"
    
    if echo "$DNS_VALUE" | grep -q "1.1.1.1\|8.8.8.8"; then
        echo -e "${GREEN}✓ DNS правильный${NC}"
    else
        echo -e "${RED}❌ DNS неправильный!${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✓ Конфигурация пересоздана!${NC}"
echo ""
echo -e "${YELLOW}Инструкции для пользователя:${NC}"
echo "  1. Удалите старую конфигурацию из WireGuard приложения"
echo "  2. Откройте бота и отправьте /devices"
echo "  3. Выберите ваше устройство или создайте новое"
echo "  4. Отсканируйте QR-код или импортируйте конфигурацию"
echo "  5. Подключитесь к VPN"

