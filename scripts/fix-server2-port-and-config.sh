#!/bin/bash

# Скрипт для исправления порта server2 и пересоздания конфига пользователя
# Использование: bash scripts/fix-server2-port-and-config.sh [TELEGRAM_ID или USER_ID]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

API_URL="${API_URL:-http://localhost:3000}"
USER_ID_OR_TELEGRAM="${1}"

if [ -z "$USER_ID_OR_TELEGRAM" ]; then
    echo -e "${YELLOW}Использование: bash scripts/fix-server2-port-and-config.sh TELEGRAM_ID или USER_ID${NC}"
    echo "Пример: bash scripts/fix-server2-port-and-config.sh 246357558"
    exit 1
fi

echo -e "${CYAN}🔧 Исправление порта server2 и пересоздание конфига...${NC}"
echo ""

# 1. Определяем USER_ID
if echo "$USER_ID_OR_TELEGRAM" | grep -qE "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"; then
    USER_ID="$USER_ID_OR_TELEGRAM"
else
    echo -e "${CYAN}Получаем USER_ID по Telegram ID: $USER_ID_OR_TELEGRAM${NC}"
    USER_RESPONSE=$(curl -s "${API_URL}/users/telegram/${USER_ID_OR_TELEGRAM}" 2>/dev/null)
    USER_ID=$(echo "$USER_RESPONSE" | python3 -c "
import sys, json
try:
    user = json.load(sys.stdin)
    print(user.get('id', ''))
except:
    pass
" 2>/dev/null || echo "$USER_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$USER_ID" ]; then
        echo -e "${RED}❌ Пользователь не найден${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ USER_ID: ${USER_ID:0:8}...${NC}"
fi

# 2. Получаем server2 с правильным портом (443)
echo ""
echo -e "${YELLOW}2. Поиск server2 с портом 443...${NC}"
SERVERS=$(curl -s "${API_URL}/wireguard/servers")
SERVER2_ID=$(echo "$SERVERS" | python3 -c "
import sys, json
try:
    servers = json.load(sys.stdin)
    for s in servers:
        if 'server2' in s.get('name', '').lower() and s.get('port') == 443:
            print(s['id'])
            break
except:
    pass
" 2>/dev/null)

if [ -z "$SERVER2_ID" ]; then
    echo -e "${RED}❌ Server2 с портом 443 не найден${NC}"
    echo -e "${YELLOW}Проверьте серверы в админке${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Server2 ID: ${SERVER2_ID:0:8}...${NC}"
echo ""

# 3. Пересоздаем конфиг пользователя
echo -e "${YELLOW}3. Пересоздание конфига пользователя...${NC}"
cd /opt/vpn-service
bash scripts/recreate-user-config.sh "$USER_ID"

echo ""
echo -e "${GREEN}✅ Готово!${NC}"
echo ""
echo -e "${YELLOW}Пользователю нужно:${NC}"
echo "  1. Удалить старую конфигурацию из WireGuard приложения"
echo "  2. Получить новую через бота (/devices)"
echo "  3. Импортировать и подключиться (будет использоваться порт 443)"

