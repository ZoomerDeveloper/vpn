#!/bin/bash

# Скрипт для получения user_id из базы данных
# Использование: 
#   bash get-user-id-db.sh TELEGRAM_ID
#   bash get-user-id-db.sh                    # показать всех пользователей

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TELEGRAM_ID="$1"

if [ -z "$TELEGRAM_ID" ]; then
    # Показать всех пользователей
    echo -e "${YELLOW}Список всех пользователей из базы данных:${NC}"
    echo ""
    
    sudo -u postgres psql -d vpn_service -c "
    SELECT 
        id,
        \"telegramId\",
        username,
        status,
        \"expireAt\",
        \"createdAt\"
    FROM users
    ORDER BY \"createdAt\" DESC;
    " 2>/dev/null
    
    echo ""
    echo -e "${YELLOW}Использование для получения конкретного пользователя:${NC}"
    echo "  bash get-user-id-db.sh TELEGRAM_ID"
    exit 0
fi

# Поиск по Telegram ID
echo -e "${YELLOW}Ищем пользователя с Telegram ID: $TELEGRAM_ID${NC}"
echo ""

RESULT=$(sudo -u postgres psql -d vpn_service -t -A -F'|' -c "
SELECT 
    id,
    \"telegramId\",
    username,
    status,
    \"expireAt\",
    \"createdAt\"
FROM users
WHERE \"telegramId\" = '$TELEGRAM_ID';
" 2>/dev/null)

if [ -z "$RESULT" ] || [ "$RESULT" == "" ]; then
    echo -e "${RED}❌ Пользователь не найден${NC}"
    echo ""
    echo -e "${YELLOW}Попробуйте:${NC}"
    echo "  1. Проверить правильность Telegram ID"
    echo "  2. Посмотреть всех пользователей: bash get-user-id-db.sh"
    exit 1
fi

# Парсим результат (формат: id|telegramId|username|status|expireAt|createdAt)
USER_ID=$(echo "$RESULT" | cut -d'|' -f1)
TELEGRAM_ID_FOUND=$(echo "$RESULT" | cut -d'|' -f2)
USERNAME=$(echo "$RESULT" | cut -d'|' -f3)
STATUS=$(echo "$RESULT" | cut -d'|' -f4)
EXPIRE_AT=$(echo "$RESULT" | cut -d'|' -f5)
CREATED_AT=$(echo "$RESULT" | cut -d'|' -f6)

echo -e "${GREEN}✓ Пользователь найден!${NC}"
echo ""
echo -e "${CYAN}User ID:${NC} ${GREEN}${USER_ID}${NC}"
echo ""
echo -e "${BLUE}Информация:${NC}"
echo "  Telegram ID: $TELEGRAM_ID_FOUND"
echo "  Username: ${USERNAME:-N/A}"
echo "  Status: $STATUS"
echo "  Expire At: ${EXPIRE_AT:-N/A}"
echo "  Created At: $CREATED_AT"
echo ""

# Проверим есть ли активные peer'ы
PEERS_COUNT=$(sudo -u postgres psql -d vpn_service -t -c "
SELECT COUNT(*) FROM vpn_peers WHERE \"userId\" = '$USER_ID' AND \"isActive\" = true;
" 2>/dev/null | xargs)

echo -e "${BLUE}Активных peer'ов:${NC} $PEERS_COUNT"
echo ""

echo -e "${YELLOW}Полезные команды:${NC}"
echo "  # Получить конфигурацию через API"
echo "  bash test-vpn-config.sh http://localhost:3000 $USER_ID"
echo ""
echo "  # Диагностика VPN"
echo "  bash diagnose-ru-vpn.sh http://localhost:3000 $USER_ID"
echo ""
echo "  # Через API напрямую"
echo "  curl http://localhost:3000/users/telegram/$TELEGRAM_ID"

