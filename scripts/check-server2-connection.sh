#!/bin/bash

# Скрипт для диагностики проблем подключения к server2
# Использование: bash scripts/check-server2-connection.sh [USER_ID или TELEGRAM_ID]

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

API_URL="${API_URL:-http://localhost:3000}"
USER_ID_OR_TELEGRAM="${1}"

echo -e "${CYAN}🔍 Диагностика подключения к server2...${NC}"
echo ""

# 1. Получить информацию о server2
echo -e "${YELLOW}1. Проверка информации о server2...${NC}"
SERVER2=$(curl -s "${API_URL}/wireguard/servers" | jq '.[] | select(.name == "server2" or .name | contains("server2"))' || echo "null")

if [ "$SERVER2" == "null" ] || [ -z "$SERVER2" ]; then
    echo -e "${RED}❌ Server2 не найден!${NC}"
    exit 1
fi

SERVER2_ID=$(echo "$SERVER2" | jq -r '.id')
SERVER2_IP=$(echo "$SERVER2" | jq -r '.publicIp // .endpoint')
SERVER2_PORT=$(echo "$SERVER2" | jq -r '.port')
SERVER2_NETWORK=$(echo "$SERVER2" | jq -r '.network')
SERVER2_MTU=$(echo "$SERVER2" | jq -r '.mtu // "не установлен"')
SERVER2_DNS=$(echo "$SERVER2" | jq -r '.dns // "не установлен"')
SERVER2_IS_HEALTHY=$(echo "$SERVER2" | jq -r '.isHealthy // true')
SERVER2_PING=$(echo "$SERVER2" | jq -r '.ping // "N/A"')

echo -e "${GREEN}✓ Server2 найден:${NC}"
echo "  ID: $SERVER2_ID"
echo "  IP: $SERVER2_IP"
echo "  Порт: $SERVER2_PORT"
echo "  Network: $SERVER2_NETWORK"
echo "  MTU: $SERVER2_MTU"
echo "  DNS: $SERVER2_DNS"
echo "  Здоров: $SERVER2_IS_HEALTHY"
echo "  Пинг: $SERVER2_PING ms"
echo ""

# 2. Проверка MTU на сервере
echo -e "${YELLOW}2. Проверка MTU на server2...${NC}"
if [ "$SERVER2_MTU" != "1280" ] && [ "$SERVER2_MTU" != "не установлен" ]; then
    echo -e "${RED}❌ MTU должен быть 1280, текущий: $SERVER2_MTU${NC}"
    echo -e "${YELLOW}💡 Решение: Запустите на server2:${NC}"
    echo "  bash scripts/fix-server-mtu.sh"
else
    echo -e "${GREEN}✓ MTU проверен (через API)${NC}"
fi
echo ""

# 3. Проверка DNS
echo -e "${YELLOW}3. Проверка DNS...${NC}"
if [ "$SERVER2_DNS" == "не установлен" ] || [ -z "$SERVER2_DNS" ]; then
    echo -e "${RED}❌ DNS не установлен!${NC}"
    echo -e "${YELLOW}💡 Решение:${NC}"
    echo "  curl -X PATCH ${API_URL}/wireguard/servers/$SERVER2_ID \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"dns\": \"1.1.1.1\"}'"
else
    echo -e "${GREEN}✓ DNS: $SERVER2_DNS${NC}"
fi
echo ""

# 4. Если указан USER_ID, проверить peer этого пользователя
if [ -n "$USER_ID_OR_TELEGRAM" ]; then
    echo -e "${YELLOW}4. Проверка peer пользователя...${NC}"
    
    # Попробуем получить по ID или Telegram ID
    USER=$(curl -s "${API_URL}/users" | jq ".[] | select(.id == \"$USER_ID_OR_TELEGRAM\" or .telegramId == \"$USER_ID_OR_TELEGRAM\")" || echo "null")
    
    if [ "$USER" == "null" ] || [ -z "$USER" ]; then
        echo -e "${RED}❌ Пользователь не найден${NC}"
    else
        USER_ID=$(echo "$USER" | jq -r '.id')
        TELEGRAM_ID=$(echo "$USER" | jq -r '.telegramId')
        
        echo -e "${GREEN}✓ Пользователь найден:${NC}"
        echo "  ID: $USER_ID"
        echo "  Telegram ID: $TELEGRAM_ID"
        
        # Получить peers этого пользователя на server2
        PEERS=$(curl -s "${API_URL}/vpn/users/${USER_ID}/peers" | jq ".[] | select(.serverId == \"$SERVER2_ID\" and .isActive == true)" || echo "null")
        
        if [ "$PEERS" == "null" ] || [ -z "$PEERS" ]; then
            echo -e "${YELLOW}⚠️  Активных peers на server2 не найдено${NC}"
        else
            PEER_ID=$(echo "$PEERS" | jq -r '.id')
            PEER_IP=$(echo "$PEERS" | jq -r '.allocatedIp')
            
            echo -e "${GREEN}✓ Peer найден:${NC}"
            echo "  Peer ID: $PEER_ID"
            echo "  IP: $PEER_IP"
            echo "  Server: server2"
            echo ""
            
            # Проверить конфиг
            echo -e "${YELLOW}5. Проверка конфигурации peer...${NC}"
            CONFIG=$(curl -s "${API_URL}/vpn/peers/${PEER_ID}/config" || echo "")
            
            if echo "$CONFIG" | grep -q "MTU = 1280"; then
                echo -e "${GREEN}✓ MTU = 1280 в конфиге${NC}"
            else
                echo -e "${RED}❌ MTU = 1280 НЕ найден в конфиге!${NC}"
                echo -e "${YELLOW}💡 Решение: Пересоздать peer${NC}"
            fi
            
            if echo "$CONFIG" | grep -q "DNS = 1.1.1.1"; then
                echo -e "${GREEN}✓ DNS = 1.1.1.1 в конфиге${NC}"
            else
                echo -e "${RED}❌ DNS = 1.1.1.1 НЕ найден в конфиге!${NC}"
                echo -e "${YELLOW}💡 Решение: Пересоздать peer${NC}"
            fi
            
            if echo "$CONFIG" | grep -q ":443"; then
                echo -e "${GREEN}✓ Порт 443 в конфиге${NC}"
            else
                echo -e "${YELLOW}⚠️  Порт не 443 (может быть проблемой)${NC}"
            fi
        fi
    fi
    echo ""
fi

# 5. Рекомендации по исправлению
echo -e "${CYAN}📋 Рекомендации по исправлению:${NC}"
echo ""
echo "1. На server2 проверьте MTU:"
echo "   ssh root@$SERVER2_IP"
echo "   grep MTU /etc/wireguard/wg0.conf"
echo "   # Должно быть: MTU = 1280"
echo "   # Если нет: bash scripts/fix-server-mtu.sh"
echo ""
echo "2. Проверьте что WireGuard запущен:"
echo "   ssh root@$SERVER2_IP 'systemctl status wg-quick@wg0'"
echo ""
echo "3. Проверьте NAT правила:"
echo "   ssh root@$SERVER2_IP 'iptables -t nat -L POSTROUTING -n | grep MASQUERADE'"
echo ""
echo "4. Если нужно пересоздать конфиг пользователя:"
if [ -n "$USER_ID" ]; then
    echo "   bash scripts/recreate-user-config.sh $USER_ID"
fi
echo ""
echo "5. Проверьте что порт открыт:"
echo "   ssh root@$SERVER2_IP 'netstat -ulnp | grep :$SERVER2_PORT'"
echo ""

