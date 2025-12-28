#!/bin/bash

# Скрипт для обновления порта server2 через API
# Использование: bash scripts/update-server2-port.sh [NEW_PORT]
# Запускается на основном сервере (где backend)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

API_URL="${API_URL:-http://localhost:3000}"
ADMIN_TOKEN="${ADMIN_TOKEN:-1qaz2wsx}"
NEW_PORT="${1:-443}"

echo -e "${CYAN}🔧 Обновление порта server2 через API...${NC}"
echo ""

# 1. Получаем список серверов
echo -e "${YELLOW}1. Получаю список серверов...${NC}"
SERVERS=$(curl -s "${API_URL}/wireguard/servers?token=${ADMIN_TOKEN}" 2>/dev/null)

if [ -z "$SERVERS" ] || echo "$SERVERS" | grep -q "error\|Error\|401\|Unauthorized"; then
    echo -e "${RED}❌ Не удалось получить список серверов${NC}"
    echo -e "${YELLOW}Проверьте что:${NC}"
    echo "  - Backend запущен"
    echo "  - API доступен: curl ${API_URL}/wireguard/servers"
    echo "  - ADMIN_TOKEN правильный в .env"
    exit 1
fi

# 2. Находим server2 с IP 92.246.128.88
echo -e "${YELLOW}2. Ищу server2 с IP 92.246.128.88...${NC}"
SERVER2_INFO=$(echo "$SERVERS" | python3 -c "
import sys, json
try:
    servers = json.load(sys.stdin)
    for s in servers:
        if 'server2' in s.get('name', '').lower() and s.get('publicIp') == '92.246.128.88':
            print(f\"{s['id']}|{s.get('port')}\")
            break
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)

if [ -z "$SERVER2_INFO" ]; then
    echo -e "${RED}❌ Server2 с IP 92.246.128.88 не найден${NC}"
    echo ""
    echo "Доступные серверы:"
    echo "$SERVERS" | python3 -c "
import sys, json
try:
    servers = json.load(sys.stdin)
    for s in servers:
        print(f\"  - {s.get('name')}: {s.get('publicIp')}:{s.get('port')}\")
except:
    pass
" 2>/dev/null
    exit 1
fi

SERVER2_ID=$(echo "$SERVER2_INFO" | cut -d'|' -f1)
CURRENT_PORT=$(echo "$SERVER2_INFO" | cut -d'|' -f2)

echo -e "${GREEN}✓ Найден server2:${NC}"
echo "  ID: ${SERVER2_ID:0:8}..."
echo "  Текущий порт: $CURRENT_PORT"
echo "  Новый порт: $NEW_PORT"
echo ""

if [ "$CURRENT_PORT" == "$NEW_PORT" ]; then
    echo -e "${YELLOW}⚠️  Порт уже установлен на $NEW_PORT${NC}"
    exit 0
fi

# 3. Обновляем порт
echo -e "${YELLOW}3. Обновляю порт через API...${NC}"
UPDATE_RESPONSE=$(curl -s -X PATCH "${API_URL}/admin/servers/${SERVER2_ID}?token=${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"port\": $NEW_PORT}" 2>/dev/null)

# Проверяем результат
if echo "$UPDATE_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    port = data.get('port')
    if port == $NEW_PORT:
        print('OK')
        sys.exit(0)
    else:
        print(f'Wrong port: {port}')
        sys.exit(1)
except:
    print('Error parsing response')
    sys.exit(1)
" 2>/dev/null; then
    echo -e "${GREEN}✓ Порт успешно обновлен до $NEW_PORT${NC}"
else
    echo -e "${RED}❌ Ошибка обновления порта${NC}"
    echo "Ответ API:"
    echo "$UPDATE_RESPONSE" | head -10
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Готово!${NC}"
echo ""
echo -e "${YELLOW}Следующие шаги:${NC}"
echo "  1. Перезапустите backend (если нужно): systemctl restart vpn-backend"
echo "  2. Пересоздайте конфиг пользователя: bash scripts/recreate-user-config.sh USER_ID"
echo "  3. Пользователю нужно получить новый конфиг через бота (/devices)"

