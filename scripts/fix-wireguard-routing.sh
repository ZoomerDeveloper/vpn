#!/bin/bash

# Скрипт для исправления маршрутизации WireGuard
# Использование: bash fix-wireguard-routing.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление маршрутизации WireGuard...${NC}"
echo ""

# Определяем основной сетевой интерфейс
MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$MAIN_IF" ]; then
    echo -e "${RED}❌ Не удалось определить основной сетевой интерфейс${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Основной интерфейс: $MAIN_IF${NC}"

# 1. Включаем IP forwarding
echo -e "${YELLOW}1. Включаю IP forwarding...${NC}"
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    sysctl -p > /dev/null
    echo -e "${GREEN}✓ IP forwarding включен в sysctl.conf${NC}"
else
    echo -e "${GREEN}✓ IP forwarding уже настроен${NC}"
fi

# Применяем немедленно
sysctl -w net.ipv4.ip_forward=1 > /dev/null
sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null

# 2. Проверяем и добавляем NAT правила
echo -e "${YELLOW}2. Проверяю NAT правила...${NC}"
MASQ_RULES=$(iptables -t nat -L POSTROUTING -v -n | grep -c "MASQUERADE.*$MAIN_IF" || echo "0")

if [ "$MASQ_RULES" == "0" ]; then
    echo -e "${YELLOW}  Добавляю NAT правило для $MAIN_IF...${NC}"
    iptables -t nat -A POSTROUTING -o "$MAIN_IF" -j MASQUERADE
    echo -e "${GREEN}✓ NAT правило добавлено${NC}"
else
    echo -e "${GREEN}✓ NAT правила уже существуют${NC}"
fi

# 3. Проверяем FORWARD правила
echo -e "${YELLOW}3. Проверяю FORWARD правила...${NC}"
WG_FORWARD_IN=$(iptables -L FORWARD -v -n | grep -c "wg0.*ACCEPT" || echo "0")

if [ "$WG_FORWARD_IN" == "0" ]; then
    echo -e "${YELLOW}  Добавляю FORWARD правила для wg0...${NC}"
    iptables -A FORWARD -i wg0 -j ACCEPT
    iptables -A FORWARD -o wg0 -j ACCEPT
    echo -e "${GREEN}✓ FORWARD правила добавлены${NC}"
else
    echo -e "${GREEN}✓ FORWARD правила уже существуют${NC}"
fi

# 4. Обновляем конфиг WireGuard с правильным интерфейсом
WG_CONFIG="/etc/wireguard/wg0.conf"
if [ -f "$WG_CONFIG" ]; then
    echo -e "${YELLOW}4. Обновляю конфиг WireGuard...${NC}"
    
    # Проверяем текущий интерфейс в PostUp
    CURRENT_IF=$(grep "PostUp.*MASQUERADE" "$WG_CONFIG" | grep -o "eth[0-9]\+\|ens[0-9]\+\|enp[0-9a-z]\+" | head -1 || echo "")
    
    if [ -n "$CURRENT_IF" ] && [ "$CURRENT_IF" != "$MAIN_IF" ]; then
        echo -e "${YELLOW}  Обнаружен неправильный интерфейс: $CURRENT_IF (должен быть $MAIN_IF)${NC}"
        
        # Создаем резервную копию
        cp "$WG_CONFIG" "${WG_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Обновляем PostUp и PostDown с правильным интерфейсом
        sed -i "s/-o $CURRENT_IF/-o $MAIN_IF/g" "$WG_CONFIG"
        echo -e "${GREEN}✓ Конфиг обновлен${NC}"
        echo -e "${YELLOW}  Перезапускаю WireGuard...${NC}"
        systemctl restart wg-quick@wg0
    else
        echo -e "${GREEN}✓ Конфиг уже использует правильный интерфейс${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Конфиг WireGuard не найден: $WG_CONFIG${NC}"
fi

# 5. Сохраняем iptables правила (если установлен iptables-persistent)
if command -v netfilter-persistent > /dev/null 2>&1; then
    echo -e "${YELLOW}5. Сохраняю iptables правила...${NC}"
    netfilter-persistent save > /dev/null 2>&1 || true
    echo -e "${GREEN}✓ Правила сохранены${NC}"
elif command -v iptables-save > /dev/null 2>&1; then
    echo -e "${YELLOW}5. Рекомендация: установите iptables-persistent для сохранения правил${NC}"
    echo -e "${YELLOW}  apt-get install iptables-persistent${NC}"
fi

echo ""
echo -e "${GREEN}✅ Маршрутизация исправлена!${NC}"
echo ""
echo -e "${BLUE}📋 Текущее состояние:${NC}"
echo -e "  Основной интерфейс: $MAIN_IF"
echo -e "  IP forwarding: $(sysctl -n net.ipv4.ip_forward)"
echo -e "  WireGuard статус: $(systemctl is-active wg-quick@wg0 2>/dev/null || echo 'не запущен')"
echo ""
echo -e "${YELLOW}Проверьте соединение на устройстве!${NC}"

