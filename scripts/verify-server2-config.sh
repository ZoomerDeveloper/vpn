#!/bin/bash

# Скрипт для проверки конфигурации server2
# Использование: bash scripts/verify-server2-config.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔍 Проверка конфигурации server2...${NC}"
echo ""

# 1. Проверка порта
echo -e "${YELLOW}1. Проверка порта:${NC}"
CURRENT_PORT=$(wg show wg0 listen-port 2>/dev/null || echo "")
CONFIG_PORT=$(grep "^ListenPort" /etc/wireguard/wg0.conf 2>/dev/null | awk '{print $3}' || echo "")

echo "  Текущий порт (wg show): $CURRENT_PORT"
echo "  Порт в конфиге: $CONFIG_PORT"

if [ "$CURRENT_PORT" == "443" ] || [ "$CONFIG_PORT" == "443" ]; then
    echo -e "${GREEN}✓ Порт 443 (рекомендуется для РФ)${NC}"
else
    echo -e "${YELLOW}⚠️  Порт не 443 (текущий: $CURRENT_PORT)${NC}"
    echo -e "${CYAN}Для РФ рекомендуется порт 443/UDP${NC}"
    echo -e "${YELLOW}Изменить порт можно через админку или:${NC}"
    echo "  bash scripts/change-wg-port.sh 443"
fi
echo ""

# 2. Проверка MTU
echo -e "${YELLOW}2. Проверка MTU:${NC}"
if grep -q "^MTU = 1280" /etc/wireguard/wg0.conf 2>/dev/null; then
    echo -e "${GREEN}✓ MTU = 1280 установлен${NC}"
else
    echo -e "${RED}❌ MTU = 1280 НЕ установлен${NC}"
    echo -e "${YELLOW}Установите: bash scripts/fix-server-mtu.sh${NC}"
fi
echo ""

# 3. Проверка peer'ов
echo -e "${YELLOW}3. Проверка peer'ов:${NC}"
PEERS_COUNT=$(wg show wg0 2>/dev/null | grep -c "peer:" || echo "0")
if [ "$PEERS_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Найдено peer'ов: $PEERS_COUNT${NC}"
    echo ""
    echo "Статус peer'ов:"
    wg show wg0 | grep -A 10 "peer:"
else
    echo -e "${YELLOW}⚠️  Peer'ов не найдено${NC}"
    echo -e "${CYAN}Peer'ы должны быть добавлены через backend API${NC}"
fi
echo ""

# 4. Проверка NAT
echo -e "${YELLOW}4. Проверка NAT правил:${NC}"
MASQ_RULES=$(iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -c "MASQUERADE" || echo "0")
if [ "$MASQ_RULES" -gt 0 ]; then
    echo -e "${GREEN}✓ NAT правила найдены: $MASQ_RULES${NC}"
else
    echo -e "${RED}❌ NAT правила не найдены${NC}"
    echo -e "${YELLOW}Добавьте: bash scripts/fix-wireguard-routing.sh${NC}"
fi
echo ""

# 5. Проверка IP forwarding
echo -e "${YELLOW}5. Проверка IP forwarding:${NC}"
FORWARDING=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
if [ "$FORWARDING" == "1" ]; then
    echo -e "${GREEN}✓ IP forwarding включен${NC}"
else
    echo -e "${RED}❌ IP forwarding выключен${NC}"
    echo -e "${YELLOW}Включите: sysctl -w net.ipv4.ip_forward=1${NC}"
fi
echo ""

# 6. Проверка публичного ключа
echo -e "${YELLOW}6. Публичный ключ сервера:${NC}"
PUBLIC_KEY=$(wg show wg0 public-key 2>/dev/null || echo "")
echo "  $PUBLIC_KEY"
echo -e "${CYAN}Этот ключ должен быть зарегистрирован в backend${NC}"
echo ""

# 7. Рекомендации
echo -e "${CYAN}📋 Рекомендации:${NC}"
echo ""
if [ "$CURRENT_PORT" != "443" ] && [ -n "$CURRENT_PORT" ]; then
    echo "1. Изменить порт на 443 (для работы в РФ):"
    echo "   bash scripts/change-wg-port.sh 443"
    echo ""
fi

if ! grep -q "^MTU = 1280" /etc/wireguard/wg0.conf 2>/dev/null; then
    echo "2. Установить MTU = 1280:"
    echo "   bash scripts/fix-server-mtu.sh"
    echo ""
fi

if [ "$PEERS_COUNT" -eq 0 ]; then
    echo "3. Peer'ы должны быть добавлены через backend автоматически"
    echo "   при создании пользователей или при восстановлении peer'ов"
    echo ""
fi

echo "4. Для работы админки нужно настроить SSH ключи на основном сервере:"
echo "   (на основном сервере) ssh-keygen -t ed25519"
echo "   (на основном сервере) ssh-copy-id root@$(hostname -I | awk '{print $1}')"
echo ""

