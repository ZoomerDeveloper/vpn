#!/bin/bash

# Диагностика почему VPN не работает на server2
# Использование: bash scripts/diagnose-server2-connection.sh [PUBLIC_KEY]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PUBLIC_KEY="${1}"

echo -e "${CYAN}🔍 Диагностика подключения на server2...${NC}"
echo ""

# 1. Проверка WireGuard
echo -e "${YELLOW}1. Проверка WireGuard:${NC}"
if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}✓ WireGuard запущен${NC}"
else
    echo -e "${RED}❌ WireGuard не запущен${NC}"
    exit 1
fi

# 2. Проверка peer'ов
echo ""
echo -e "${YELLOW}2. Проверка peer'ов:${NC}"
WG_STATUS=$(wg show wg0 2>/dev/null)

if [ -z "$PUBLIC_KEY" ]; then
    echo "Все peer'ы на сервере:"
    echo "$WG_STATUS"
else
    if echo "$WG_STATUS" | grep -q "$PUBLIC_KEY"; then
        echo -e "${GREEN}✓ Peer найден на сервере${NC}"
        echo ""
        echo "Статус peer'а:"
        echo "$WG_STATUS" | grep -A 10 "$PUBLIC_KEY"
    else
        echo -e "${RED}❌ Peer НЕ найден на сервере!${NC}"
        echo -e "${YELLOW}Peer должен быть добавлен через backend${NC}"
        echo ""
        echo "Все peer'ы на сервере:"
        echo "$WG_STATUS"
    fi
fi

# 3. Проверка NAT правил
echo ""
echo -e "${YELLOW}3. Проверка NAT правил:${NC}"
MASQ_RULES=$(iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -c "MASQUERADE" || echo "0")

if [ "$MASQ_RULES" -gt 0 ]; then
    echo -e "${GREEN}✓ NAT правила найдены: $MASQ_RULES${NC}"
    echo ""
    echo "NAT правила:"
    iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE | head -5
else
    echo -e "${RED}❌ NAT правила НЕ найдены!${NC}"
    echo -e "${YELLOW}Это критично - трафик не будет работать${NC}"
fi

# 4. Проверка IP forwarding
echo ""
echo -e "${YELLOW}4. Проверка IP forwarding:${NC}"
FORWARDING=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
if [ "$FORWARDING" == "1" ]; then
    echo -e "${GREEN}✓ IP forwarding включен${NC}"
else
    echo -e "${RED}❌ IP forwarding выключен!${NC}"
    echo -e "${YELLOW}Включите: sysctl -w net.ipv4.ip_forward=1${NC}"
fi

# 5. Проверка интерфейсов
echo ""
echo -e "${YELLOW}5. Проверка сетевых интерфейсов:${NC}"
MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)
WG_IF="wg0"

echo "  Основной интерфейс: $MAIN_IF"
echo "  WireGuard интерфейс: $WG_IF"

if ip link show "$WG_IF" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Интерфейс $WG_IF существует${NC}"
    WG_IP=$(ip addr show "$WG_IF" | grep "inet " | awk '{print $2}')
    echo "  IP адрес: $WG_IP"
else
    echo -e "${RED}❌ Интерфейс $WG_IF не найден${NC}"
fi

# 6. Проверка MTU на сервере
echo ""
echo -e "${YELLOW}6. Проверка MTU:${NC}"
WG_MTU=$(ip link show wg0 2>/dev/null | grep -oP 'mtu \K[0-9]+' || echo "")
CONFIG_MTU=$(grep "^MTU" /etc/wireguard/wg0.conf 2>/dev/null | awk '{print $3}' || echo "")

if [ -n "$WG_MTU" ]; then
    if [ "$WG_MTU" == "1280" ]; then
        echo -e "${GREEN}✓ MTU интерфейса: $WG_MTU${NC}"
    else
        echo -e "${YELLOW}⚠️  MTU интерфейса: $WG_MTU (рекомендуется 1280)${NC}"
    fi
fi

if [ -n "$CONFIG_MTU" ]; then
    echo "  MTU в конфиге: $CONFIG_MTU"
fi

# 7. Проверка маршрутизации
echo ""
echo -e "${YELLOW}7. Проверка маршрутизации:${NC}"
echo "Таблица маршрутизации для wg0:"
ip route show dev wg0 2>/dev/null || echo "  (нет маршрутов)"

# 8. Рекомендации
echo ""
echo -e "${CYAN}📋 Рекомендации:${NC}"

if [ "$MASQ_RULES" -eq 0 ]; then
    echo ""
    echo -e "${RED}❌ КРИТИЧНО: NAT правила отсутствуют${NC}"
    echo "Исправление:"
    NETWORK=$(grep "^Address" /etc/wireguard/wg0.conf | head -1 | awk '{print $3}' | cut -d'/' -f1 | sed 's/\.[0-9]*$/.0/24')
    echo "  iptables -t nat -A POSTROUTING -s $NETWORK -o $MAIN_IF -j MASQUERADE"
    echo "  apt install -y iptables-persistent"
    echo "  netfilter-persistent save"
fi

if [ "$FORWARDING" != "1" ]; then
    echo ""
    echo -e "${RED}❌ КРИТИЧНО: IP forwarding выключен${NC}"
    echo "Исправление:"
    echo "  sysctl -w net.ipv4.ip_forward=1"
    echo "  echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf"
fi

if [ -z "$PUBLIC_KEY" ] || ! echo "$WG_STATUS" | grep -q "$PUBLIC_KEY"; then
    echo ""
    echo -e "${RED}❌ КРИТИЧНО: Peer не добавлен на сервер${NC}"
    echo "Peer должен быть добавлен через backend API"
    echo "Проверьте логи backend или добавьте peer вручную"
fi

echo ""

