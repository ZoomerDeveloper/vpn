#!/bin/bash

# Скрипт для проверки почему админка не видит статус подключения
# Использование: bash scripts/check-admin-ssh-status.sh [TELEGRAM_ID или USER_ID]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

API_URL="${API_URL:-http://localhost:3000}"
USER_ID_OR_TELEGRAM="${1}"

if [ -z "$USER_ID_OR_TELEGRAM" ]; then
    echo -e "${YELLOW}Использование: bash scripts/check-admin-ssh-status.sh TELEGRAM_ID или USER_ID${NC}"
    echo "Пример: bash scripts/check-admin-ssh-status.sh 246357558"
    exit 1
fi

echo -e "${CYAN}🔍 Проверка почему админка не видит статус подключения...${NC}"
echo ""

# 1. Определяем USER_ID
if echo "$USER_ID_OR_TELEGRAM" | grep -qE "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"; then
    USER_ID="$USER_ID_OR_TELEGRAM"
else
    echo -e "${CYAN}Получаем USER_ID по Telegram ID: $USER_ID_OR_TELEGRAM${NC}"
    USER_RESPONSE=$(curl -s "${API_URL}/users/telegram/${USER_ID_OR_TELEGRAM}" 2>/dev/null)
    USER_ID=$(echo "$USER_RESPONSE" | python3 -c "
import sys, json
try:
    user = json.load(sys.stdin)
    print(user.get('id', ''))
except:
    pass
" 2>/dev/null || echo "$USER_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$USER_ID" ]; then
        echo -e "${RED}❌ Пользователь не найден${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ USER_ID: ${USER_ID:0:8}...${NC}"
echo ""

# 2. Получаем peer'ы пользователя
echo -e "${YELLOW}2. Проверка peer'ов пользователя...${NC}"
PEERS=$(curl -s "${API_URL}/vpn/users/${USER_ID}/peers")
PEER_INFO=$(echo "$PEERS" | python3 -c "
import sys, json
try:
    peers = json.load(sys.stdin)
    if isinstance(peers, list):
        for p in peers:
            if p.get('isActive'):
                print(f\"{p.get('id')}|{p.get('publicKey')}|{p.get('serverId')}|{p.get('allocatedIp')}\")
                break
except:
    pass
" 2>/dev/null)

if [ -z "$PEER_INFO" ]; then
    echo -e "${RED}❌ Активных peer'ов не найдено${NC}"
    exit 1
fi

PEER_ID=$(echo "$PEER_INFO" | cut -d'|' -f1)
PUBLIC_KEY=$(echo "$PEER_INFO" | cut -d'|' -f2)
SERVER_ID=$(echo "$PEER_INFO" | cut -d'|' -f3)
ALLOCATED_IP=$(echo "$PEER_INFO" | cut -d'|' -f4)

echo -e "${GREEN}✓ Peer найден:${NC}"
echo "  Peer ID: ${PEER_ID:0:8}..."
echo "  Public Key: ${PUBLIC_KEY:0:32}..."
echo "  Server ID: ${SERVER_ID:0:8}..."
echo "  Allocated IP: $ALLOCATED_IP"
echo ""

# 3. Получаем информацию о сервере
echo -e "${YELLOW}3. Проверка сервера...${NC}"
SERVERS=$(curl -s "${API_URL}/wireguard/servers")
SERVER_INFO=$(echo "$SERVERS" | python3 -c "
import sys, json
try:
    servers = json.load(sys.stdin)
    for s in servers:
        if s.get('id') == '$SERVER_ID':
            print(f\"{s.get('name')}|{s.get('publicIp')}|{s.get('host')}|{s.get('port')}\")
            break
except:
    pass
" 2>/dev/null)

if [ -z "$SERVER_INFO" ]; then
    echo -e "${RED}❌ Сервер не найден${NC}"
    exit 1
fi

SERVER_NAME=$(echo "$SERVER_INFO" | cut -d'|' -f1)
SERVER_PUBLIC_IP=$(echo "$SERVER_INFO" | cut -d'|' -f2)
SERVER_HOST=$(echo "$SERVER_INFO" | cut -d'|' -f3)
SERVER_PORT=$(echo "$SERVER_INFO" | cut -d'|' -f4)

echo -e "${GREEN}✓ Сервер найден:${NC}"
echo "  Name: $SERVER_NAME"
echo "  Public IP: $SERVER_PUBLIC_IP"
echo "  Host: $SERVER_HOST"
echo "  Port: $SERVER_PORT"
echo ""

# 4. Проверяем SSH подключение
echo -e "${YELLOW}4. Проверка SSH подключения к серверу...${NC}"
SSH_HOST="$SERVER_PUBLIC_IP"
if [ -z "$SSH_HOST" ]; then
    SSH_HOST="$SERVER_HOST"
fi

echo "  Пробуем подключиться: ssh root@$SSH_HOST"
if ssh -o BatchMode=yes -o ConnectTimeout=5 root@$SSH_HOST "echo 'SSH OK'" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH подключение работает${NC}"
else
    echo -e "${RED}❌ SSH подключение не работает${NC}"
    echo -e "${YELLOW}Проверьте SSH ключи${NC}"
    exit 1
fi
echo ""

# 5. Проверяем WireGuard статус на сервере
echo -e "${YELLOW}5. Проверка WireGuard статуса на сервере...${NC}"
WG_STATUS=$(ssh -o BatchMode=yes root@$SSH_HOST "wg show wg0 2>&1" 2>/dev/null)

if echo "$WG_STATUS" | grep -q "$PUBLIC_KEY"; then
    echo -e "${GREEN}✓ Peer найден на сервере!${NC}"
    echo ""
    echo "Статус peer'а:"
    echo "$WG_STATUS" | grep -A 10 "$PUBLIC_KEY"
else
    echo -e "${RED}❌ Peer НЕ найден на сервере${NC}"
    echo ""
    echo "Все peer'ы на сервере:"
    echo "$WG_STATUS" | head -30
    echo ""
    echo -e "${YELLOW}⚠️  Peer не добавлен на сервер физически!${NC}"
    echo -e "${CYAN}Нужно восстановить peer на сервере${NC}"
fi
echo ""

# 6. Проверяем что админка видит
echo -e "${YELLOW}6. Проверка что возвращает админка...${NC}"
ADMIN_STATUS=$(curl -s "${API_URL}/admin/users?token=${ADMIN_TOKEN:-1qaz2wsx}" 2>/dev/null)

USER_STATUS=$(echo "$ADMIN_STATUS" | python3 -c "
import sys, json
try:
    users = json.load(sys.stdin)
    for u in users:
        if u.get('id') == '$USER_ID':
            peers = u.get('peers', [])
            for p in peers:
                if p.get('id') == '$PEER_ID':
                    conn = p.get('connectionStatus', {})
                    print(f\"{conn.get('connected', False)}|{conn.get('latestHandshake', 'N/A')}\")
                    break
            break
except Exception as e:
    print(f'Error: {e}')
" 2>/dev/null)

if [ -n "$USER_STATUS" ]; then
    CONNECTED=$(echo "$USER_STATUS" | cut -d'|' -f1)
    HANDSHAKE=$(echo "$USER_STATUS" | cut -d'|' -f2)
    
    if [ "$CONNECTED" == "True" ]; then
        echo -e "${GREEN}✓ Админка видит подключение${NC}"
    else
        echo -e "${YELLOW}⚠️  Админка не видит подключение${NC}"
        echo "  Handshake: $HANDSHAKE"
    fi
else
    echo -e "${YELLOW}⚠️  Не удалось получить статус из админки${NC}"
fi

echo ""
echo -e "${CYAN}📋 Резюме:${NC}"
echo "  1. SSH: $SSH_HOST"
echo "  2. Peer на сервере: $(echo "$WG_STATUS" | grep -q "$PUBLIC_KEY" && echo '✓ Да' || echo '❌ Нет')"
echo "  3. Админка видит: $(echo "$CONNECTED" | grep -q "True" && echo '✓ Да' || echo '❌ Нет')"
echo ""

