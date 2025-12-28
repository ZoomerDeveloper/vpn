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
    
    # Проверяем что ответ не пустой
    if [ -z "$SERVERS" ] || echo "$SERVERS" | grep -q "^\[\]$"; then
        echo -e "${RED}❌ Серверы не найдены${NC}"
        echo -e "${YELLOW}Ответ API:${NC}"
        echo "$SERVERS"
        exit 1
    fi
    
    # Извлекаем первый ID из JSON массива (используем более надежный способ)
    # Пробуем разные методы извлечения
    SERVER_ID=$(echo "$SERVERS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data[0]['id'] if isinstance(data, list) and len(data) > 0 else '')" 2>/dev/null)
    
    # Если Python не сработал, пробуем grep
    if [ -z "$SERVER_ID" ]; then
        SERVER_ID=$(echo "$SERVERS" | grep -oP '"id"\s*:\s*"\K[^"]+' | head -1)
    fi
    
    if [ -z "$SERVER_ID" ]; then
        echo -e "${RED}❌ Не удалось извлечь ID сервера${NC}"
        echo -e "${YELLOW}Ответ API:${NC}"
        echo "$SERVERS" | head -30
        echo ""
        echo -e "${YELLOW}Альтернативные варианты:${NC}"
        echo "  1. Укажите ID сервера вручную:"
        echo "     bash update-server-dns.sh $API_URL SERVER_ID"
        echo ""
        echo "  2. Обновите через базу данных:"
        echo "     bash update-dns-db.sh"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Найден сервер: ${SERVER_ID:0:8}...${NC}"
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

