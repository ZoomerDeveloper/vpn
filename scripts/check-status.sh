#!/bin/bash

# Скрипт для проверки статуса системы
# Использование: ./check-status.sh [API_URL]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_URL="${1:-http://localhost:3000}"

echo -e "${BLUE}🔍 Проверка статуса системы...${NC}"
echo ""

# 1. Проверка Backend API
echo -e "${YELLOW}1. Проверка Backend API...${NC}"
if curl -s "${API_URL}/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Backend API доступен${NC}"
else
    echo -e "${RED}❌ Backend API недоступен${NC}"
    exit 1
fi

# 2. Проверка WireGuard серверов
echo -e "${YELLOW}2. Проверка WireGuard серверов...${NC}"
SERVERS=$(curl -s "${API_URL}/wireguard/servers")
SERVER_COUNT=$(echo "$SERVERS" | grep -o '"id"' | wc -l || echo "0")

if [ "$SERVER_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Найдено WireGuard серверов: $SERVER_COUNT${NC}"
    echo "$SERVERS" | grep -o '"name":"[^"]*"' | head -5 | while read line; do
        NAME=$(echo "$line" | cut -d'"' -f4)
        echo "  - $NAME"
    done
else
    echo -e "${RED}❌ WireGuard серверы не найдены!${NC}"
    echo -e "${YELLOW}  Запустите: bash scripts/register-wireguard-server.sh${NC}"
fi

# 3. Проверка тарифов
echo -e "${YELLOW}3. Проверка тарифов...${NC}"
TARIFFS=$(curl -s "${API_URL}/tariffs")
TARIFF_COUNT=$(echo "$TARIFFS" | grep -o '"id"' | wc -l || echo "0")

if [ "$TARIFF_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Найдено тарифов: $TARIFF_COUNT${NC}"
else
    echo -e "${RED}❌ Тарифы не найдены!${NC}"
    echo -e "${YELLOW}  Запустите: npx ts-node src/database/seeds/seed.ts${NC}"
fi

# 4. Проверка PostgreSQL
echo -e "${YELLOW}4. Проверка PostgreSQL...${NC}"
if systemctl is-active --quiet postgresql; then
    echo -e "${GREEN}✓ PostgreSQL запущен${NC}"
else
    echo -e "${RED}❌ PostgreSQL не запущен${NC}"
fi

# 5. Проверка WireGuard сервиса
echo -e "${YELLOW}5. Проверка WireGuard...${NC}"
if systemctl is-active --quiet wg-quick@wg0 2>/dev/null; then
    echo -e "${GREEN}✓ WireGuard запущен${NC}"
else
    echo -e "${YELLOW}⚠️  WireGuard не запущен (может быть нормально если это Application Server)${NC}"
fi

echo ""
echo -e "${BLUE}📋 Резюме:${NC}"
if [ "$SERVER_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ КРИТИЧНО: WireGuard серверы не зарегистрированы!${NC}"
    echo -e "${YELLOW}  Для исправления запустите:${NC}"
    echo "    bash scripts/register-wireguard-server.sh"
fi

