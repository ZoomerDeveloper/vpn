#!/bin/bash

# Скрипт для обновления DNS на всех серверах для лучшей работы в РФ
# Использование: bash fix-dns-russia.sh [API_URL] [DNS]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_URL="${1:-http://localhost:3000}"
DNS="${2:-1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4}"

echo -e "${BLUE}🔧 Обновление DNS для работы в РФ...${NC}"
echo ""

# 1. Обновляем через API
echo -e "${YELLOW}1. Получаем список серверов...${NC}"
SERVERS=$(curl -s "${API_URL}/wireguard/servers" 2>/dev/null)

if [ -z "$SERVERS" ] || echo "$SERVERS" | grep -q "Cannot GET"; then
    echo -e "${RED}❌ Не удалось получить серверы через API${NC}"
    echo -e "${YELLOW}Пробуем через базу данных...${NC}"
    
    # Обновляем через БД напрямую
    sudo -u postgres psql -d vpn_service -c "UPDATE vpn_servers SET dns = '${DNS}';" 2>/dev/null
    echo -e "${GREEN}✓ DNS обновлен в базе данных${NC}"
    exit 0
fi

# Парсим серверы
SERVER_IDS=$(echo "$SERVERS" | python3 -c "
import sys, json
try:
    servers = json.load(sys.stdin)
    if isinstance(servers, list):
        for s in servers:
            print(s['id'])
except:
    pass
" 2>/dev/null)

if [ -z "$SERVER_IDS" ]; then
    SERVER_IDS=$(echo "$SERVERS" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$SERVER_IDS" ]; then
    echo -e "${RED}❌ Серверы не найдены${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Найдено серверов: $(echo "$SERVER_IDS" | wc -l)${NC}"
echo ""

# Обновляем каждый сервер
for SERVER_ID in $SERVER_IDS; do
    echo -e "${YELLOW}Обновляю сервер ${SERVER_ID:0:8}...${NC}"
    
    UPDATE_RESPONSE=$(curl -s -X PATCH "${API_URL}/wireguard/servers/${SERVER_ID}" \
        -H "Content-Type: application/json" \
        -d "{\"dns\": \"${DNS}\"}" 2>/dev/null)
    
    if [ -n "$UPDATE_RESPONSE" ] && ! echo "$UPDATE_RESPONSE" | grep -q "error\|Error"; then
        echo -e "${GREEN}✓ Сервер ${SERVER_ID:0:8} обновлен${NC}"
    else
        echo -e "${RED}❌ Ошибка обновления сервера ${SERVER_ID:0:8}${NC}"
    fi
done

# 2. Также обновляем в БД на всякий случай
echo ""
echo -e "${YELLOW}2. Обновляю DNS в базе данных...${NC}"
sudo -u postgres psql -d vpn_service -c "UPDATE vpn_servers SET dns = '${DNS}';" 2>/dev/null
echo -e "${GREEN}✓ DNS обновлен в базе данных${NC}"

echo ""
echo -e "${GREEN}✓ DNS обновлен на всех серверах${NC}"
echo ""
echo -e "${YELLOW}⚠️  ВАЖНО:${NC}"
echo "  Пользователям нужно ПЕРЕСОЗДАТЬ конфигурацию VPN, чтобы получить новый DNS!"
echo "  Старые конфигурации содержат старый DNS."
echo ""
echo -e "${CYAN}Для пересоздания конфигурации пользователя:${NC}"
echo "  bash recreate-user-config.sh USER_ID"

