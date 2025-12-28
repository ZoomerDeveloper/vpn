#!/bin/bash

# Скрипт для восстановления peer на server2
# Использование: bash scripts/restore-peer-on-server2.sh [TELEGRAM_ID или USER_ID]

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
    echo -e "${YELLOW}Использование: bash scripts/restore-peer-on-server2.sh TELEGRAM_ID или USER_ID${NC}"
    echo "Пример: bash scripts/restore-peer-on-server2.sh 246357558"
    exit 1
fi

echo -e "${CYAN}🔧 Восстановление peer на server2...${NC}"
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

# 2. Получаем активный peer пользователя на server2
echo -e "${YELLOW}2. Получаю peer пользователя...${NC}"
PEERS=$(curl -s "${API_URL}/vpn/users/${USER_ID}/peers" 2>/dev/null)

# Находим peer на server2
PEER_INFO=$(echo "$PEERS" | python3 -c "
import sys, json
try:
    peers = json.load(sys.stdin)
    if isinstance(peers, list):
        for p in peers:
            if p.get('isActive'):
                # Проверяем что это server2 (по IP или имени)
                server_id = p.get('serverId', '')
                # Получаем информацию о сервере
                import urllib.request
                import os
                api_url = os.environ.get('API_URL', 'http://localhost:3000')
                server_resp = urllib.request.urlopen(f'{api_url}/wireguard/servers/{server_id}').read()
                server = json.loads(server_resp.decode())
                if 'server2' in server.get('name', '').lower() or server.get('publicIp') == '92.246.128.88':
                    print(f\"{p.get('id')}|{p.get('publicKey')}|{p.get('allocatedIp')}|{p.get('presharedKey', '')}|{server_id}\")
                    break
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
" 2>/dev/null)

if [ -z "$PEER_INFO" ]; then
    echo -e "${RED}❌ Активный peer на server2 не найден${NC}"
    echo -e "${YELLOW}Создаю новый peer...${NC}"
    
    # Создаем новый peer
    NEW_PEER=$(curl -s -X POST "${API_URL}/vpn/users/${USER_ID}/peers" \
      -H "Content-Type: application/json" 2>/dev/null)
    
    if [ -z "$NEW_PEER" ]; then
        echo -e "${RED}❌ Ошибка создания peer${NC}"
        exit 1
    fi
    
    PEER_INFO=$(echo "$NEW_PEER" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    peer = data.get('peer', {})
    print(f\"{peer.get('id')}|{peer.get('publicKey')}|{peer.get('allocatedIp')}|{peer.get('presharedKey', '')}|{peer.get('serverId')}\")
except:
    pass
" 2>/dev/null)
fi

if [ -z "$PEER_INFO" ]; then
    echo -e "${RED}❌ Не удалось получить информацию о peer${NC}"
    exit 1
fi

PEER_ID=$(echo "$PEER_INFO" | cut -d'|' -f1)
PUBLIC_KEY=$(echo "$PEER_INFO" | cut -d'|' -f2)
ALLOCATED_IP=$(echo "$PEER_INFO" | cut -d'|' -f3)
PRESHARED_KEY=$(echo "$PEER_INFO" | cut -d'|' -f4)
SERVER_ID=$(echo "$PEER_INFO" | cut -d'|' -f5)

echo -e "${GREEN}✓ Peer найден:${NC}"
echo "  Peer ID: ${PEER_ID:0:8}..."
echo "  Public Key: ${PUBLIC_KEY:0:32}..."
echo "  Allocated IP: $ALLOCATED_IP"
echo "  Server ID: ${SERVER_ID:0:8}..."
echo ""

# 3. Восстанавливаем peer через API
echo -e "${YELLOW}3. Восстанавливаю peer на сервере через API...${NC}"
RESTORE_RESPONSE=$(curl -s -X PATCH "${API_URL}/vpn/peers/${PEER_ID}/activate" \
  -H "Content-Type: application/json" \
  -d "{\"userId\": \"${USER_ID}\"}" 2>/dev/null)

if echo "$RESTORE_RESPONSE" | grep -q "activated\|success"; then
    echo -e "${GREEN}✓ Peer активирован${NC}"
else
    echo -e "${YELLOW}⚠️  Ответ API: $RESTORE_RESPONSE${NC}"
fi

# 4. Проверяем что peer добавлен на server2
echo ""
echo -e "${YELLOW}4. Проверяю что peer добавлен на server2...${NC}"
sleep 2

# Проверяем через SSH (если скрипт запущен на основном сервере)
if ssh -o BatchMode=yes -o ConnectTimeout=3 root@92.246.128.88 "wg show wg0 | grep -q '$PUBLIC_KEY'" 2>/dev/null; then
    echo -e "${GREEN}✓ Peer найден на server2!${NC}"
else
    echo -e "${YELLOW}⚠️  Peer пока не найден на server2${NC}"
    echo -e "${CYAN}Проверьте логи backend или добавьте peer вручную:${NC}"
    echo ""
    echo "На server2 выполните:"
    echo "  wg set wg0 peer $PUBLIC_KEY allowed-ips $ALLOCATED_IP"
    if [ -n "$PRESHARED_KEY" ]; then
        echo "  wg set wg0 peer $PUBLIC_KEY preshared-key <(echo '$PRESHARED_KEY')"
    fi
fi

echo ""
echo -e "${GREEN}✅ Готово!${NC}"

