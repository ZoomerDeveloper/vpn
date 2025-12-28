#!/bin/bash

# Скрипт для обновления порта server2 в базе данных
# Использование: bash scripts/fix-server2-port-db.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

API_URL="${API_URL:-http://localhost:3000}"
NEW_PORT="${1:-443}"

echo -e "${CYAN}🔧 Обновление порта server2 в базе данных...${NC}"
echo ""

# Получаем все серверы (с токеном если нужен)
ADMIN_TOKEN="${ADMIN_TOKEN:-1qaz2wsx}"
SERVERS=$(curl -s "${API_URL}/wireguard/servers?token=${ADMIN_TOKEN}" 2>/dev/null || curl -s "${API_URL}/wireguard/servers" 2>/dev/null)

if [ -z "$SERVERS" ] || echo "$SERVERS" | grep -q "error\|Error\|401"; then
    echo -e "${RED}❌ Не удалось получить список серверов${NC}"
    echo -e "${YELLOW}Проверьте что:${NC}"
    echo "  - Backend запущен"
    echo "  - API доступен: curl ${API_URL}/wireguard/servers"
    echo "  - Вы на основном сервере (где backend)"
    exit 1
fi

# Находим все server2
echo -e "${YELLOW}Найденные server2:${NC}"
echo "$SERVERS" | python3 -c "
import sys, json
try:
    servers = json.load(sys.stdin)
    server2_list = [s for s in servers if 'server2' in s.get('name', '').lower()]
    for s in server2_list:
        print(f\"ID: {s['id'][:8]}... | Name: {s['name']} | Port: {s.get('port')} | PublicIP: {s.get('publicIp')}\")
except Exception as e:
    print(f'Error: {e}')
" 2>/dev/null

# Находим server2 с правильным IP (92.246.128.88)
SERVER2_ID=$(echo "$SERVERS" | python3 -c "
import sys, json
try:
    servers = json.load(sys.stdin)
    for s in servers:
        if 'server2' in s.get('name', '').lower() and s.get('publicIp') == '92.246.128.88':
            print(s['id'])
            break
except:
    pass
" 2>/dev/null)

if [ -z "$SERVER2_ID" ]; then
    echo -e "${RED}❌ Server2 с IP 92.246.128.88 не найден${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Найден server2 ID: ${SERVER2_ID:0:8}...${NC}"

# Обновляем порт через API
echo ""
echo -e "${YELLOW}Обновляю порт на $NEW_PORT через API...${NC}"

UPDATE_RESPONSE=$(curl -s -X PATCH "${API_URL}/admin/servers/${SERVER2_ID}?token=${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"port\": $NEW_PORT}" 2>/dev/null)
  
echo "Ответ API: $UPDATE_RESPONSE"

if echo "$UPDATE_RESPONSE" | grep -q "\"port\":.*$NEW_PORT"; then
    echo -e "${GREEN}✓ Порт обновлен через API${NC}"
else
    echo -e "${YELLOW}⚠️  Ответ API:${NC}"
    echo "$UPDATE_RESPONSE" | head -5
    echo ""
    echo -e "${YELLOW}Пробую через прямую БД...${NC}"
    
    # Альтернатива: обновить напрямую в БД
    if command -v psql > /dev/null 2>&1; then
        # Нужно загрузить DB credentials из .env
        if [ -f "/opt/vpn-service/backend/.env" ]; then
            source <(grep -E "^DB_" /opt/vpn-service/backend/.env | sed 's/^/export /')
            sudo -u postgres psql -d "$DB_DATABASE" -c "UPDATE vpn_servers SET port = $NEW_PORT WHERE id = '$SERVER2_ID';" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Порт обновлен в базе данных${NC}"
            else
                echo -e "${RED}❌ Ошибка обновления в БД${NC}"
            fi
        else
            echo -e "${RED}❌ Файл .env не найден${NC}"
        fi
    else
        echo -e "${RED}❌ psql не установлен${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✅ Готово!${NC}"
echo ""
echo -e "${YELLOW}Важно:${NC}"
echo "  1. Перезапустите backend: systemctl restart vpn-backend"
echo "  2. Пересоздайте конфиг пользователя: bash scripts/recreate-user-config.sh USER_ID"
echo "  3. Пользователю нужно получить новый конфиг через бота"

