#!/bin/bash

# Скрипт для диагностики и исправления проблем подключения VPN для пользователя из России
# Использование: bash fix-peer-connection-ru.sh ALLOCATED_IP [USER_ID]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ALLOCATED_IP="$1"
USER_ID="$2"

if [ -z "$ALLOCATED_IP" ]; then
    echo -e "${RED}❌ Ошибка: Не указан allocated IP${NC}"
    echo -e "${YELLOW}Использование: bash fix-peer-connection-ru.sh ALLOCATED_IP [USER_ID]${NC}"
    echo "Пример: bash fix-peer-connection-ru.sh 10.0.0.34"
    exit 1
fi

API_URL="${API_URL:-http://localhost:3000}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"

echo -e "${BLUE}🔍 Диагностика подключения VPN для IP: ${ALLOCATED_IP}${NC}"
echo ""

# 1. Проверяем WireGuard статус
echo -e "${YELLOW}1. Проверка WireGuard статуса...${NC}"
if command -v wg > /dev/null 2>&1; then
    WG_STATUS=$(sudo wg show wg0 2>&1 || wg show wg0 2>&1)
    if echo "$WG_STATUS" | grep -q "$ALLOCATED_IP"; then
        echo -e "${GREEN}✓ Peer найден в WireGuard${NC}"
        echo "$WG_STATUS" | grep -A 10 "$ALLOCATED_IP" || true
    else
        echo -e "${RED}✗ Peer не найден в WireGuard${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  WireGuard не установлен локально${NC}"
fi
echo ""

# 2. Проверяем IP forwarding
echo -e "${YELLOW}2. Проверка IP forwarding...${NC}"
if [ -f /proc/sys/net/ipv4/ip_forward ]; then
    IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
    if [ "$IP_FORWARD" = "1" ]; then
        echo -e "${GREEN}✓ IP forwarding включен${NC}"
    else
        echo -e "${RED}✗ IP forwarding выключен${NC}"
        echo -e "${YELLOW}Включение IP forwarding...${NC}"
        echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null
        echo -e "${GREEN}✓ IP forwarding включен${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Не удалось проверить IP forwarding${NC}"
fi
echo ""

# 3. Проверяем iptables правила
echo -e "${YELLOW}3. Проверка iptables правил...${NC}"
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$MAIN_INTERFACE" ]; then
    MAIN_INTERFACE=$(ip route | grep default | awk '{print $3}' | head -1)
fi

if [ -z "$MAIN_INTERFACE" ]; then
    echo -e "${RED}✗ Не удалось определить основной сетевой интерфейс${NC}"
else
    echo -e "${GREEN}✓ Основной интерфейс: ${MAIN_INTERFACE}${NC}"
    
    # Проверяем NAT правило
    NAT_RULE=$(sudo iptables -t nat -C POSTROUTING -o "$MAIN_INTERFACE" -j MASQUERADE 2>&1 || echo "not found")
    if echo "$NAT_RULE" | grep -q "not found\|Bad rule"; then
        echo -e "${RED}✗ NAT правило не найдено${NC}"
        echo -e "${YELLOW}Добавление NAT правила...${NC}"
        sudo iptables -t nat -A POSTROUTING -o "$MAIN_INTERFACE" -j MASQUERADE
        echo -e "${GREEN}✓ NAT правило добавлено${NC}"
    else
        echo -e "${GREEN}✓ NAT правило существует${NC}"
    fi
    
    # Проверяем FORWARD правило для WireGuard
    FORWARD_RULE=$(sudo iptables -C FORWARD -i wg0 -o "$MAIN_INTERFACE" -j ACCEPT 2>&1 || echo "not found")
    if echo "$FORWARD_RULE" | grep -q "not found\|Bad rule"; then
        echo -e "${YELLOW}⚠️  FORWARD правило для wg0 не найдено (может быть не нужно)${NC}"
    else
        echo -e "${GREEN}✓ FORWARD правило существует${NC}"
    fi
fi
echo ""

# 4. Проверяем DNS в WireGuard конфигурации
echo -e "${YELLOW}4. Рекомендации по DNS...${NC}"
echo "Для России рекомендуется использовать следующие DNS серверы:"
echo "  - Cloudflare: 1.1.1.1, 1.0.0.1"
echo "  - Google: 8.8.8.8, 8.8.4.4"
echo "  - AdGuard: 94.140.14.14, 94.140.15.15"
echo "  - Quad9: 9.9.9.9, 149.112.112.112"
echo ""

# 5. Если передан USER_ID, проверяем через API
if [ -n "$USER_ID" ]; then
    echo -e "${YELLOW}5. Проверка через API...${NC}"
    if [ -z "$ADMIN_TOKEN" ]; then
        echo -e "${YELLOW}⚠️  ADMIN_TOKEN не установлен, пропускаем API проверку${NC}"
    else
        USER_DATA=$(curl -s "${API_URL}/admin/users/${USER_ID}?token=${ADMIN_TOKEN}" || echo "")
        if [ -n "$USER_DATA" ]; then
            echo -e "${GREEN}✓ Пользователь найден в базе${NC}"
            PEERS=$(echo "$USER_DATA" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    peers = data.get('peers', [])
    for p in peers:
        if p.get('allocatedIp', '').startswith('${ALLOCATED_IP}'):
            print(f\"Peer ID: {p.get('id')}, Server: {p.get('server', {}).get('name', 'N/A')}\")
except:
    pass
" 2>/dev/null || echo "")
            echo "$PEERS"
        else
            echo -e "${RED}✗ Не удалось получить данные пользователя${NC}"
        fi
    fi
    echo ""
fi

# 6. Рекомендации
echo -e "${BLUE}📋 Рекомендации для исправления:${NC}"
echo ""
echo "1. Убедитесь что DNS правильно настроен в конфигурации WireGuard пользователя"
echo "2. Проверьте что порт WireGuard не заблокирован (попробуйте сменить на 443/UDP)"
echo "3. Если проблема сохраняется, попробуйте мигрировать пользователя на другой сервер через админку"
echo "4. Проверьте логи WireGuard: sudo journalctl -u wg-quick@wg0 -n 50"
echo ""
echo -e "${GREEN}✅ Диагностика завершена${NC}"

