#!/bin/bash

# Подробная диагностика VPN для пользователей из РФ
# Использование: bash diagnose-vpn-ru-detailed.sh [USER_ID]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

API_URL="${1:-http://localhost:3000}"
USER_ID="${2}"

echo -e "${BLUE}🔍 Подробная диагностика VPN для РФ...${NC}"
echo ""

if [ -z "$USER_ID" ]; then
    echo -e "${YELLOW}Использование: bash diagnose-vpn-ru-detailed.sh [API_URL] USER_ID${NC}"
    echo "Пример: bash diagnose-vpn-ru-detailed.sh http://localhost:3000 USER_ID"
    exit 1
fi

# 1. Проверка конфигурации пользователя
echo -e "${YELLOW}1. Проверка конфигурации пользователя:${NC}"
PEERS=$(curl -s "${API_URL}/vpn/users/${USER_ID}/peers" 2>/dev/null)

if echo "$PEERS" | grep -q "\[\]"; then
    echo -e "${RED}❌ У пользователя нет активных peer'ов${NC}"
    exit 1
fi

PEER_ID=$(echo "$PEERS" | python3 -c "
import sys, json
try:
    peers = json.load(sys.stdin)
    if isinstance(peers, list) and len(peers) > 0:
        print(peers[0]['id'])
except:
    pass
" 2>/dev/null)

if [ -z "$PEER_ID" ]; then
    PEER_ID=$(echo "$PEERS" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

if [ -z "$PEER_ID" ]; then
    echo -e "${RED}❌ Не удалось получить ID peer'а${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Peer ID: ${PEER_ID:0:8}...${NC}"

CONFIG_RESPONSE=$(curl -s "${API_URL}/vpn/peers/${PEER_ID}/config" 2>/dev/null)
CONFIG=$(echo "$CONFIG_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('config', ''))
except:
    pass
" 2>/dev/null)

if [ -z "$CONFIG" ]; then
    CONFIG=$(echo "$CONFIG_RESPONSE" | grep -o '"config":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g')
fi

echo ""
echo -e "${BLUE}📄 Текущая конфигурация:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$CONFIG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 2. Анализ конфигурации
echo -e "${YELLOW}2. Анализ конфигурации:${NC}"

DNS_LINE=$(echo "$CONFIG" | grep "^DNS = " || true)
if [ -n "$DNS_LINE" ]; then
    DNS_VALUE=$(echo "$DNS_LINE" | cut -d'=' -f2 | xargs)
    echo -e "  DNS: ${CYAN}${DNS_VALUE}${NC}"
    
    # Проверяем что используются правильные DNS
    if echo "$DNS_VALUE" | grep -qE "1\.1\.1\.1|8\.8\.8\.8|1\.0\.0\.1|8\.8\.4\.4"; then
        echo -e "  ${GREEN}✓ DNS содержит надежные серверы${NC}"
    else
        echo -e "  ${RED}❌ DNS может быть проблемой!${NC}"
        echo -e "  ${YELLOW}  Рекомендуется: 1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4${NC}"
    fi
else
    echo -e "  ${RED}❌ DNS не указан в конфигурации!${NC}"
fi

ALLOWED_IPS=$(echo "$CONFIG" | grep "^AllowedIPs = " | cut -d'=' -f2 | xargs || echo "")
if [ -n "$ALLOWED_IPS" ]; then
    echo -e "  AllowedIPs: ${CYAN}${ALLOWED_IPS}${NC}"
    if echo "$ALLOWED_IPS" | grep -q "0.0.0.0/0"; then
        echo -e "  ${GREEN}✓ Весь трафик идет через VPN${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Не весь трафик идет через VPN${NC}"
    fi
fi

ENDPOINT=$(echo "$CONFIG" | grep "^Endpoint = " | cut -d'=' -f2 | xargs || echo "")
if [ -n "$ENDPOINT" ]; then
    ENDPOINT_IP=$(echo "$ENDPOINT" | cut -d':' -f1)
    ENDPOINT_PORT=$(echo "$ENDPOINT" | cut -d':' -f2)
    echo -e "  Endpoint: ${CYAN}${ENDPOINT}${NC}"
    
    # Проверяем доступность endpoint
    if timeout 3 bash -c "echo > /dev/tcp/${ENDPOINT_IP}/${ENDPOINT_PORT}" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Endpoint доступен${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Endpoint недоступен с этого сервера (это нормально)${NC}"
    fi
fi

# 3. Проверка на WireGuard сервере
echo ""
echo -e "${YELLOW}3. Проверка WireGuard на сервере:${NC}"

if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}✓ WireGuard запущен${NC}"
    
    # Получаем публичный ключ peer'а
    PUBLIC_KEY=$(echo "$PEERS" | python3 -c "
import sys, json
try:
    peers = json.load(sys.stdin)
    if isinstance(peers, list) and len(peers) > 0:
        print(peers[0].get('publicKey', ''))
except:
    pass
" 2>/dev/null)
    
    if [ -n "$PUBLIC_KEY" ]; then
        echo -e "  Публичный ключ: ${PUBLIC_KEY:0:16}..."
        
        # Проверяем handshake
        WG_OUTPUT=$(wg show wg0 2>/dev/null | grep -A 5 "peer: ${PUBLIC_KEY}" || echo "")
        if [ -n "$WG_OUTPUT" ]; then
            HANDSHAKE=$(echo "$WG_OUTPUT" | grep "latest handshake" || echo "")
            if [ -n "$HANDSHAKE" ]; then
                echo -e "  ${GREEN}✓ Peer найден на сервере${NC}"
                echo -e "  ${CYAN}${HANDSHAKE}${NC}"
                
                # Проверяем время последнего handshake
                if echo "$HANDSHAKE" | grep -q "second\|minute\|hour"; then
                    echo -e "  ${GREEN}✓ Handshake был недавно${NC}"
                else
                    echo -e "  ${RED}❌ Handshake был давно или отсутствует!${NC}"
                fi
            else
                echo -e "  ${YELLOW}⚠️  Peer найден, но handshake отсутствует${NC}"
            fi
            
            TRANSFER=$(echo "$WG_OUTPUT" | grep "transfer" || echo "")
            if [ -n "$TRANSFER" ]; then
                echo -e "  ${CYAN}${TRANSFER}${NC}"
            fi
        else
            echo -e "  ${RED}❌ Peer не найден на сервере!${NC}"
        fi
    fi
else
    echo -e "${RED}❌ WireGuard не запущен${NC}"
fi

# 4. Проверка маршрутизации
echo ""
echo -e "${YELLOW}4. Проверка маршрутизации:${NC}"

FORWARDING=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
if [ "$FORWARDING" == "1" ]; then
    echo -e "${GREEN}✓ IP forwarding включен${NC}"
else
    echo -e "${RED}❌ IP forwarding выключен${NC}"
fi

# Проверяем NAT правила
MASQ_RULES=$(iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -c "MASQUERADE" || echo "0")
if [ "$MASQ_RULES" -gt 0 ]; then
    echo -e "${GREEN}✓ NAT правила настроены (${MASQ_RULES} правил)${NC}"
else
    echo -e "${RED}❌ NAT правила отсутствуют${NC}"
fi

# 5. Рекомендации для РФ
echo ""
echo -e "${YELLOW}5. Рекомендации для работы в РФ:${NC}"
echo ""

echo -e "${CYAN}На стороне пользователя:${NC}"
echo "  1. Убедитесь что используется НОВАЯ конфигурация с правильным DNS"
echo "  2. Проверьте что DNS в конфигурации содержит: 1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4"
echo "  3. После импорта конфигурации перезапустите WireGuard"
echo "  4. Проверьте что VPN подключен (зеленая точка в приложении)"
echo ""
echo -e "${CYAN}Проверка на устройстве пользователя:${NC}"
echo "  - IP адрес должен быть IP сервера: curl ifconfig.me"
echo "  - DNS резолвинг: nslookup google.com"
echo "  - Доступность сайтов: curl -v https://google.com"
echo ""
echo -e "${CYAN}Если не работает:${NC}"
echo "  1. Пересоздайте конфигурацию (удалите старую и создайте новую)"
echo "  2. Попробуйте другой DNS (например, только 1.1.1.1)"
echo "  3. Проверьте что AllowedIPs = 0.0.0.0/0,::/0"
echo "  4. Убедитесь что порт WireGuard не заблокирован провайдером"
echo ""

# 6. Генерация улучшенной конфигурации для РФ
echo -e "${YELLOW}6. Предлагаемая конфигурация для РФ:${NC}"
echo ""
echo -e "${CYAN}Оптимальный DNS для РФ:${NC}"
echo "  1.1.1.1,1.0.0.1  (Cloudflare - обычно лучше работает)"
echo "  или"
echo "  8.8.8.8,8.8.4.4  (Google DNS)"
echo "  или"
echo "  1.1.1.1,8.8.8.8  (комбинация)"
echo ""

echo -e "${GREEN}Диагностика завершена!${NC}"

