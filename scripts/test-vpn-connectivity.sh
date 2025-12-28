#!/bin/bash

# Скрипт для проверки подключения WireGuard peer'а
# Использование: bash test-vpn-connectivity.sh [PEER_PUBLIC_KEY]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PEER_PUBLIC_KEY="${1}"

echo -e "${BLUE}🔍 Проверка подключения WireGuard peer'а...${NC}"
echo ""

if [ -z "$PEER_PUBLIC_KEY" ]; then
    echo -e "${YELLOW}Использование: bash test-vpn-connectivity.sh PEER_PUBLIC_KEY${NC}"
    echo ""
    echo -e "${CYAN}Показываю все активные peer'ы:${NC}"
    sudo wg show wg0 | grep -A 5 "peer:" || echo "Нет активных peer'ов"
    exit 1
fi

# Проверяем статус peer'а
WG_OUTPUT=$(sudo wg show wg0 2>/dev/null | grep -A 10 "peer: ${PEER_PUBLIC_KEY}" || echo "")

if [ -z "$WG_OUTPUT" ]; then
    echo -e "${RED}❌ Peer не найден на сервере${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Peer найден${NC}"
echo ""

# Извлекаем информацию
ENDPOINT=$(echo "$WG_OUTPUT" | grep "endpoint:" | awk '{print $2}' || echo "")
HANDSHAKE=$(echo "$WG_OUTPUT" | grep "latest handshake:" || echo "")
TRANSFER=$(echo "$WG_OUTPUT" | grep "transfer:" || echo "")
ALLOWED_IPS=$(echo "$WG_OUTPUT" | grep "allowed ips:" | awk '{print $3}' || echo "")

echo -e "${CYAN}Информация о peer'е:${NC}"
if [ -n "$ENDPOINT" ]; then
    echo "  Endpoint: $ENDPOINT"
    
    ENDPOINT_IP=$(echo "$ENDPOINT" | cut -d':' -f1)
    ENDPOINT_PORT=$(echo "$ENDPOINT" | cut -d':' -f2)
    
    # Проверяем откуда подключился peer
    echo "  IP клиента: ${CYAN}${ENDPOINT_IP}${NC}"
    
    # Определяем локацию (примерно)
    if echo "$ENDPOINT_IP" | grep -qE "^31\.|^77\.|^178\.|^95\.|^217\."; then
        echo "  ${YELLOW}⚠️  Похоже на IP из России${NC}"
    fi
fi

if [ -n "$HANDSHAKE" ]; then
    echo "  $HANDSHAKE"
    
    # Проверяем время последнего handshake
    if echo "$HANDSHAKE" | grep -qE "second|minute"; then
        echo -e "  ${GREEN}✓ Подключение активно${NC}"
    elif echo "$HANDSHAKE" | grep -qE "hour"; then
        HOURS=$(echo "$HANDSHAKE" | grep -oE "[0-9]+ hour" | grep -oE "[0-9]+")
        if [ -n "$HOURS" ] && [ "$HOURS" -lt 2 ]; then
            echo -e "  ${YELLOW}⚠️  Подключение было недавно (${HOURS} час)${NC}"
        else
            echo -e "  ${RED}❌ Handshake был давно${NC}"
        fi
    else
        echo -e "  ${RED}❌ Handshake отсутствует или был очень давно${NC}"
    fi
else
    echo -e "  ${RED}❌ Handshake отсутствует${NC}"
fi

if [ -n "$TRANSFER" ]; then
    echo "  $TRANSFER"
    
    # Проверяем есть ли трафик
    RECEIVED=$(echo "$TRANSFER" | grep -oE "[0-9.]+ [KMGT]?iB received" | grep -oE "[0-9.]+" || echo "0")
    if [ "$RECEIVED" != "0" ]; then
        echo -e "  ${GREEN}✓ Есть входящий трафик${NC}"
    fi
fi

if [ -n "$ALLOWED_IPS" ]; then
    echo "  Allowed IPs: $ALLOWED_IPS"
fi

echo ""
echo -e "${CYAN}Рекомендации:${NC}"
if [ -z "$HANDSHAKE" ] || echo "$HANDSHAKE" | grep -qE "day|week|month"; then
    echo "  ${YELLOW}⚠️  Peer не подключается. Возможные причины:${NC}"
    echo "    1. Порт WireGuard заблокирован провайдером (попробуйте изменить порт)"
    echo "    2. Пользователь не подключил VPN"
    echo "    3. Проблемы с сетью пользователя"
    echo "    4. Firewall блокирует соединение"
fi

