#!/bin/bash

# Скрипт для обновления DNS сервера WireGuard для лучшей работы в РФ
# Использование: bash update-server-dns.sh [API_URL] [SERVER_ID] [DNS]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_URL="${1:-http://localhost:3000}"
SERVER_ID="${2}"
DNS="${3:-1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4}"

echo -e "${BLUE}🔧 Обновление DNS для WireGuard сервера...${NC}"
echo ""

if [ -z "$SERVER_ID" ]; then
    echo -e "${YELLOW}Получаю список серверов...${NC}"
    SERVERS=$(curl -s "${API_URL}/wireguard/servers")
    
    if echo "$SERVERS" | grep -q "\[\]"; then
        echo -e "${RED}❌ Серверы не найдены${NC}"
        exit 1
    fi
    
    echo "$SERVERS" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4 | while read id; do
        SERVER_ID="$id"
        break
    done
    
    if [ -z "$SERVER_ID" ]; then
        echo -e "${RED}❌ Не удалось найти сервер${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Обновляю DNS для сервера: $SERVER_ID${NC}"
echo -e "${GREEN}Новый DNS: $DNS${NC}"

# Обновляем DNS через API
RESPONSE=$(curl -s -X PATCH "${API_URL}/wireguard/servers/${SERVER_ID}" \
    -H "Content-Type: application/json" \
    -d "{\"dns\": \"$DNS\"}")

if echo "$RESPONSE" | grep -q "\"id\""; then
    echo -e "${GREEN}✅ DNS успешно обновлен!${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Важно:${NC}"
    echo -e "${YELLOW}Существующие клиенты должны пересоздать конфигурацию, чтобы получить новый DNS.${NC}"
    echo -e "${YELLOW}Новые клиенты получат обновленный DNS автоматически.${NC}"
else
    echo -e "${RED}❌ Ошибка при обновлении DNS:${NC}"
    echo "$RESPONSE"
    exit 1
fi

