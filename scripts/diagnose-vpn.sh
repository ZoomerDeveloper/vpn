#!/bin/bash

# Скрипт для диагностики проблем с VPN
# Использование: bash diagnose-vpn.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Диагностика VPN сервера...${NC}"
echo ""

# 1. Проверка WireGuard
echo -e "${YELLOW}1. Проверка WireGuard:${NC}"
if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}✓ WireGuard запущен${NC}"
    PEERS=$(wg show wg0 2>/dev/null | grep -c "peer:" || echo "0")
    echo -e "  Активных peer'ов: $PEERS"
else
    echo -e "${RED}❌ WireGuard не запущен${NC}"
fi

# 2. Проверка маршрутизации
echo -e "${YELLOW}2. Проверка маршрутизации:${NC}"
FORWARDING=$(sysctl -n net.ipv4.ip_forward)
if [ "$FORWARDING" == "1" ]; then
    echo -e "${GREEN}✓ IP forwarding включен${NC}"
else
    echo -e "${RED}❌ IP forwarding выключен${NC}"
fi

MASQ_RULES=$(iptables -t nat -L POSTROUTING -v -n | grep -c "MASQUERADE" || echo "0")
echo -e "  NAT правил: $MASQ_RULES"

# 3. Проверка DNS в базе данных
echo -e "${YELLOW}3. Проверка DNS конфигурации:${NC}"
if command -v psql > /dev/null 2>&1; then
    DNS_CONFIG=$(sudo -u postgres psql -d vpn_service -t -c "SELECT dns FROM vpn_servers LIMIT 1;" 2>/dev/null | xargs)
    if [ -n "$DNS_CONFIG" ]; then
        echo -e "  Текущий DNS: $DNS_CONFIG"
        if echo "$DNS_CONFIG" | grep -q "1.1.1.1\|8.8.8.8"; then
            echo -e "${GREEN}✓ DNS настроен${NC}"
        else
            echo -e "${YELLOW}⚠️  Рекомендуется использовать 1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  DNS не найден в БД${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  PostgreSQL не доступен для проверки${NC}"
fi

# 4. Проверка портов
echo -e "${YELLOW}4. Проверка портов:${NC}"
if ss -tuln | grep -q ":51820"; then
    echo -e "${GREEN}✓ Порт 51820/UDP открыт${NC}"
else
    echo -e "${RED}❌ Порт 51820/UDP не слушается${NC}"
fi

# 5. Проверка доступности DNS
echo -e "${YELLOW}5. Проверка доступности DNS:${NC}"
if dig @1.1.1.1 google.com +short > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Cloudflare DNS (1.1.1.1) доступен${NC}"
else
    echo -e "${YELLOW}⚠️  Cloudflare DNS недоступен${NC}"
fi

if dig @8.8.8.8 google.com +short > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Google DNS (8.8.8.8) доступен${NC}"
else
    echo -e "${YELLOW}⚠️  Google DNS недоступен${NC}"
fi

# 6. Рекомендации
echo ""
echo -e "${BLUE}📋 Рекомендации:${NC}"

if [ "$DNS_CONFIG" != "1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4" ]; then
    echo -e "${YELLOW}→ Обновите DNS для лучшей работы в РФ:${NC}"
    echo "  bash scripts/update-server-dns.sh"
fi

echo ""
echo -e "${GREEN}Диагностика завершена!${NC}"

