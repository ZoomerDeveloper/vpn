#!/bin/bash

# Скрипт для проверки WireGuard на server2
# Использование: bash scripts/check-wireguard-server2.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔍 Проверка WireGuard на server2...${NC}"
echo ""

# 1. Проверка установки WireGuard
echo -e "${YELLOW}1. Проверка установки WireGuard:${NC}"
if command -v wg > /dev/null 2>&1; then
    WG_VERSION=$(wg --version 2>&1 | head -1)
    echo -e "${GREEN}✓ WireGuard установлен: $WG_VERSION${NC}"
else
    echo -e "${RED}❌ WireGuard не установлен${NC}"
    echo -e "${YELLOW}Установите: apt update && apt install -y wireguard${NC}"
    exit 1
fi

# 2. Проверка статуса WireGuard
echo ""
echo -e "${YELLOW}2. Проверка статуса WireGuard:${NC}"
if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}✓ WireGuard запущен${NC}"
    systemctl status wg-quick@wg0 --no-pager -l | head -10
else
    echo -e "${RED}❌ WireGuard не запущен${NC}"
    echo -e "${YELLOW}Запустите: systemctl start wg-quick@wg0${NC}"
fi

# 3. Проверка конфигурации
echo ""
echo -e "${YELLOW}3. Проверка конфигурации:${NC}"
if [ -f /etc/wireguard/wg0.conf ]; then
    echo -e "${GREEN}✓ Конфиг найден: /etc/wireguard/wg0.conf${NC}"
    
    # Проверка MTU
    if grep -q "^MTU = 1280" /etc/wireguard/wg0.conf; then
        echo -e "${GREEN}✓ MTU = 1280 установлен${NC}"
    else
        echo -e "${YELLOW}⚠️  MTU = 1280 не установлен${NC}"
        echo -e "${CYAN}Установите: bash scripts/fix-server-mtu.sh${NC}"
    fi
    
    # Проверка порта
    PORT=$(grep "^ListenPort" /etc/wireguard/wg0.conf | awk '{print $3}')
    if [ -n "$PORT" ]; then
        echo -e "${GREEN}✓ Порт: $PORT${NC}"
    else
        echo -e "${YELLOW}⚠️  Порт не указан${NC}"
    fi
else
    echo -e "${RED}❌ Конфиг не найден${NC}"
    echo -e "${YELLOW}Создайте: bash scripts/setup-wireguard.sh${NC}"
fi

# 4. Проверка peer'ов
echo ""
echo -e "${YELLOW}4. Активные peer'ы:${NC}"
if systemctl is-active --quiet wg-quick@wg0; then
    PEERS_COUNT=$(wg show wg0 2>/dev/null | grep -c "peer:" || echo "0")
    if [ "$PEERS_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Найдено peer'ов: $PEERS_COUNT${NC}"
        wg show wg0 | head -20
    else
        echo -e "${YELLOW}⚠️  Peer'ов не найдено${NC}"
    fi
else
    echo -e "${RED}❌ Не могу проверить peer'ы (WireGuard не запущен)${NC}"
fi

# 5. Проверка NAT правил
echo ""
echo -e "${YELLOW}5. Проверка NAT правил:${NC}"
MASQ_RULES=$(iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -c "MASQUERADE" || echo "0")
if [ "$MASQ_RULES" -gt 0 ]; then
    echo -e "${GREEN}✓ NAT правила найдены: $MASQ_RULES${NC}"
    iptables -t nat -L POSTROUTING -n | grep MASQUERADE
else
    echo -e "${YELLOW}⚠️  NAT правила не найдены${NC}"
    echo -e "${CYAN}Добавьте через: bash scripts/fix-wireguard-routing.sh${NC}"
fi

# 6. Проверка IP forwarding
echo ""
echo -e "${YELLOW}6. Проверка IP forwarding:${NC}"
FORWARDING=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
if [ "$FORWARDING" == "1" ]; then
    echo -e "${GREEN}✓ IP forwarding включен${NC}"
else
    echo -e "${RED}❌ IP forwarding выключен${NC}"
    echo -e "${YELLOW}Включите: sysctl -w net.ipv4.ip_forward=1${NC}"
fi

echo ""
echo -e "${CYAN}✅ Проверка завершена${NC}"

