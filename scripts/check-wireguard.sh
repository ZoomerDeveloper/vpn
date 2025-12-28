#!/bin/bash

# Скрипт для проверки состояния WireGuard
# Использование: bash check-wireguard.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка WireGuard...${NC}"
echo ""

# 1. Проверка статуса WireGuard
echo -e "${YELLOW}1. Статус WireGuard сервиса:${NC}"
if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}✓ WireGuard запущен${NC}"
else
    echo -e "${RED}❌ WireGuard не запущен${NC}"
    echo -e "${YELLOW}  Запуск: sudo systemctl start wg-quick@wg0${NC}"
fi

# 2. Проверка интерфейса
echo -e "${YELLOW}2. Проверка интерфейса wg0:${NC}"
if ip link show wg0 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Интерфейс wg0 существует${NC}"
    ip addr show wg0 | grep -E "inet |state" || echo -e "${YELLOW}  IP адрес не назначен${NC}"
else
    echo -e "${RED}❌ Интерфейс wg0 не найден${NC}"
fi

# 3. Проверка peers
echo -e "${YELLOW}3. Активные peers:${NC}"
if command -v wg > /dev/null 2>&1; then
    PEERS=$(wg show wg0 2>/dev/null | grep -c "peer:" || echo "0")
    if [ "$PEERS" -gt 0 ]; then
        echo -e "${GREEN}✓ Найдено peers: $PEERS${NC}"
        echo ""
        wg show wg0 | head -20
    else
        echo -e "${YELLOW}⚠️  Peer'ов не найдено${NC}"
    fi
else
    echo -e "${RED}❌ Команда 'wg' не найдена${NC}"
fi

# 4. Проверка IP forwarding
echo -e "${YELLOW}4. IP Forwarding:${NC}"
FORWARDING=$(sysctl -n net.ipv4.ip_forward)
if [ "$FORWARDING" == "1" ]; then
    echo -e "${GREEN}✓ IP forwarding включен${NC}"
else
    echo -e "${RED}❌ IP forwarding выключен${NC}"
    echo -e "${YELLOW}  Включение: sudo sysctl -w net.ipv4.ip_forward=1${NC}"
    echo -e "${YELLOW}  Постоянно: добавить в /etc/sysctl.conf: net.ipv4.ip_forward=1${NC}"
fi

# 5. Проверка iptables правил
echo -e "${YELLOW}5. Проверка iptables правил:${NC}"
MASQ_RULES=$(iptables -t nat -L POSTROUTING -v -n | grep -c "MASQUERADE" || echo "0")
if [ "$MASQ_RULES" -gt 0 ]; then
    echo -e "${GREEN}✓ NAT правила найдены: $MASQ_RULES${NC}"
    iptables -t nat -L POSTROUTING -v -n | grep MASQUERADE | head -5
else
    echo -e "${RED}❌ NAT правила не найдены${NC}"
    echo -e "${YELLOW}  Добавление: sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE${NC}"
    echo -e "${YELLOW}  (замените eth0 на ваш основной сетевой интерфейс)${NC}"
fi

# 6. Проверка firewall
echo -e "${YELLOW}6. Проверка firewall:${NC}"
if command -v ufw > /dev/null 2>&1; then
    UFW_STATUS=$(ufw status | head -1 | grep -o "active\|inactive")
    echo -e "${YELLOW}  UFW статус: $UFW_STATUS${NC}"
    if [ "$UFW_STATUS" == "active" ]; then
        UFW_WG=$(ufw status | grep -c "51820" || echo "0")
        if [ "$UFW_WG" -gt 0 ]; then
            echo -e "${GREEN}✓ Правило для порта 51820 найдено${NC}"
        else
            echo -e "${YELLOW}⚠️  Правило для порта 51820 не найдено${NC}"
            echo -e "${YELLOW}  Добавление: sudo ufw allow 51820/udp${NC}"
        fi
    fi
fi

# 7. Проверка основного интерфейса
echo -e "${YELLOW}7. Основной сетевой интерфейс:${NC}"
MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -n "$MAIN_IF" ]; then
    echo -e "${GREEN}✓ Основной интерфейс: $MAIN_IF${NC}"
else
    echo -e "${RED}❌ Основной интерфейс не найден${NC}"
fi

echo ""
echo -e "${BLUE}📋 Резюме:${NC}"
if [ "$FORWARDING" != "1" ]; then
    echo -e "${RED}❌ КРИТИЧНО: IP forwarding выключен!${NC}"
fi
if [ "$MASQ_RULES" == "0" ]; then
    echo -e "${RED}❌ КРИТИЧНО: NAT правила отсутствуют!${NC}"
fi

