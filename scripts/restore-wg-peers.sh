#!/bin/bash

# Скрипт для восстановления WireGuard peer'ов после перезапуска
# Использование: bash restore-wg-peers.sh [API_URL] [USER_ID]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_URL="${1:-http://localhost:3000}"
USER_ID="${2}"

echo -e "${BLUE}🔧 Восстановление WireGuard peer'ов...${NC}"
echo ""

if [ -z "$USER_ID" ]; then
    echo -e "${YELLOW}Использование: bash restore-wg-peers.sh [API_URL] USER_ID${NC}"
    echo "Пример: bash restore-wg-peers.sh http://localhost:3000 47c0b409-4729-4d5c-b51d-8b4d25b54994"
    echo ""
    echo -e "${YELLOW}Или укажите Telegram ID для автоматического поиска пользователя:${NC}"
    exit 1
fi

# Получаем список peer'ов пользователя
echo -e "${YELLOW}Получаю список peer'ов для пользователя: $USER_ID...${NC}"
PEERS=$(curl -s "${API_URL}/vpn/users/${USER_ID}/peers")

if echo "$PEERS" | grep -q "not found\|404\|\[\]"; then
    echo -e "${RED}❌ Peer'ы не найдены для пользователя $USER_ID${NC}"
    exit 1
fi

# Извлекаем ID peer'ов
PEER_IDS=$(echo "$PEERS" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$PEER_IDS" ]; then
    echo -e "${YELLOW}⚠️  Активных peer'ов не найдено${NC}"
    exit 0
fi

PEER_COUNT=$(echo "$PEER_IDS" | wc -l)
echo -e "${GREEN}✓ Найдено активных peer'ов: $PEER_COUNT${NC}"
echo ""

# Активируем каждый peer
for PEER_ID in $PEER_IDS; do
    echo -e "${YELLOW}Активирую peer: ${PEER_ID:0:8}...${NC}"
    RESPONSE=$(curl -s -X PATCH "${API_URL}/vpn/peers/${PEER_ID}/activate" \
        -H "Content-Type: application/json" \
        -d '{}')
    
    if echo "$RESPONSE" | grep -q "\"message\".*activated\|activated"; then
        echo -e "${GREEN}✓ Peer активирован${NC}"
    else
        echo -e "${YELLOW}⚠️  Peer уже активен или ошибка: $RESPONSE${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ Восстановление завершено!${NC}"
echo ""
echo -e "${BLUE}Проверьте статус:${NC}"
echo "  sudo wg show wg0"

