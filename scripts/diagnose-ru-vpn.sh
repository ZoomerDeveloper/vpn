#!/bin/bash

# Скрипт для диагностики проблем с VPN в РФ
# Использование: bash diagnose-ru-vpn.sh [API_URL] [USER_ID]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_URL="${1:-http://localhost:3000}"
USER_ID="${2}"

echo -e "${BLUE}🔍 Диагностика VPN для пользователей из РФ...${NC}"
echo ""

# 1. Проверка DNS в базе данных
echo -e "${YELLOW}1. Проверка DNS в базе данных:${NC}"
if command -v psql > /dev/null 2>&1; then
    DNS_FROM_DB=$(sudo -u postgres psql -d vpn_service -t -c "SELECT dns FROM vpn_servers LIMIT 1;" 2>/dev/null | xargs)
    if [ -n "$DNS_FROM_DB" ]; then
        echo -e "  DNS в БД: $DNS_FROM_DB"
        if echo "$DNS_FROM_DB" | grep -q "1.1.1.1\|8.8.8.8"; then
            echo -e "${GREEN}✓ DNS настроен${NC}"
        else
            echo -e "${RED}❌ DNS не настроен правильно${NC}"
            echo -e "${YELLOW}  Обновите: bash update-dns-db.sh${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  DNS не найден в БД${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  PostgreSQL не доступен${NC}"
fi

# 2. Проверка DNS через API
echo -e "${YELLOW}2. Проверка DNS через API:${NC}"
SERVERS=$(curl -s "${API_URL}/wireguard/servers" 2>/dev/null)
if [ -n "$SERVERS" ] && echo "$SERVERS" | grep -q "dns"; then
    DNS_FROM_API=$(echo "$SERVERS" | grep -o '"dns":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$DNS_FROM_API" ]; then
        echo -e "  DNS через API: $DNS_FROM_API"
        echo -e "${GREEN}✓ DNS доступен через API${NC}"
    else
        echo -e "${YELLOW}⚠️  DNS не найден в ответе API${NC}"
    fi
else
    echo -e "${RED}❌ Не удалось получить серверы через API${NC}"
fi

# 3. Проверка конфигурации пользователя
if [ -n "$USER_ID" ]; then
    echo -e "${YELLOW}3. Проверка конфигурации пользователя:${NC}"
    PEERS=$(curl -s "${API_URL}/vpn/users/${USER_ID}/peers" 2>/dev/null)
    
    if echo "$PEERS" | grep -q "\[\]"; then
        echo -e "${YELLOW}⚠️  У пользователя нет активных peer'ов${NC}"
    else
        PEER_ID=$(echo "$PEERS" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$PEER_ID" ]; then
            CONFIG_RESPONSE=$(curl -s "${API_URL}/vpn/peers/${PEER_ID}/config" 2>/dev/null)
            CONFIG=$(echo "$CONFIG_RESPONSE" | grep -o '"config":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g')
            
            if [ -n "$CONFIG" ]; then
                echo -e "${GREEN}✓ Конфигурация получена${NC}"
                echo ""
                echo -e "${BLUE}Содержимое конфигурации:${NC}"
                echo "$CONFIG" | head -15
                echo ""
                
                # Проверяем DNS в конфигурации
                CONFIG_DNS=$(echo "$CONFIG" | grep "^DNS = " | cut -d'=' -f2 | xargs)
                if [ -n "$CONFIG_DNS" ]; then
                    echo -e "  DNS в конфигурации: $CONFIG_DNS"
                    if echo "$CONFIG_DNS" | grep -q "1.1.1.1\|8.8.8.8"; then
                        echo -e "${GREEN}✓ DNS в конфигурации правильный${NC}"
                    else
                        echo -e "${RED}❌ DNS в конфигурации неправильный!${NC}"
                        echo -e "${YELLOW}  Пользователю нужно пересоздать конфигурацию${NC}"
                    fi
                else
                    echo -e "${RED}❌ DNS не найден в конфигурации!${NC}"
                fi
            else
                echo -e "${RED}❌ Не удалось получить конфигурацию${NC}"
            fi
        fi
    fi
fi

# 4. Проверка WireGuard на сервере
echo -e "${YELLOW}4. Проверка WireGuard на сервере:${NC}"
if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}✓ WireGuard запущен${NC}"
    
    ACTIVE_PEERS=$(wg show wg0 2>/dev/null | grep -c "peer:" || echo "0")
    echo -e "  Активных peer'ов: $ACTIVE_PEERS"
    
    if [ "$ACTIVE_PEERS" -gt 0 ]; then
        echo ""
        echo -e "${BLUE}Статус peer'ов:${NC}"
        wg show wg0 | grep -A 5 "peer:" | head -20
    fi
else
    echo -e "${RED}❌ WireGuard не запущен${NC}"
fi

# 5. Проверка маршрутизации
echo -e "${YELLOW}5. Проверка маршрутизации:${NC}"
FORWARDING=$(sysctl -n net.ipv4.ip_forward)
if [ "$FORWARDING" == "1" ]; then
    echo -e "${GREEN}✓ IP forwarding включен${NC}"
else
    echo -e "${RED}❌ IP forwarding выключен${NC}"
fi

MASQ_RULES=$(iptables -t nat -L POSTROUTING -v -n | grep -c "MASQUERADE" || echo "0")
if [ "$MASQ_RULES" -gt 0 ]; then
    echo -e "${GREEN}✓ NAT правила настроены ($MASQ_RULES правил)${NC}"
else
    echo -e "${RED}❌ NAT правила отсутствуют${NC}"
fi

# 6. Проверка доступности DNS
echo -e "${YELLOW}6. Проверка доступности DNS серверов:${NC}"
for dns in "1.1.1.1" "8.8.8.8"; do
    if dig @$dns google.com +short +timeout=2 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $dns доступен${NC}"
    else
        echo -e "${RED}❌ $dns недоступен${NC}"
    fi
done

# 7. Рекомендации
echo ""
echo -e "${BLUE}📋 Рекомендации:${NC}"

if [ -z "$USER_ID" ]; then
    echo -e "${YELLOW}→ Для проверки конфигурации пользователя укажите USER_ID:${NC}"
    echo "  bash diagnose-ru-vpn.sh $API_URL USER_ID"
fi

echo ""
echo -e "${YELLOW}→ Для проверки на стороне пользователя:${NC}"
echo "  1. Проверьте что VPN подключен"
echo "  2. Проверьте IP адрес (должен быть IP VPN сервера):"
echo "     curl ifconfig.me"
echo "  3. Проверьте DNS резолвинг:"
echo "     nslookup google.com"
echo "  4. Проверьте что DNS в конфигурации правильный (должен содержать 1.1.1.1 или 8.8.8.8)"

echo ""
echo -e "${GREEN}Диагностика завершена!${NC}"

