#!/bin/bash

# Скрипт для получения user_id по Telegram ID
# Использование: 
#   bash get-user-id.sh TELEGRAM_ID
#   bash get-user-id.sh                    # показать всех пользователей

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

API_URL="${API_URL:-http://localhost:3000}"
TELEGRAM_ID="$1"

echo -e "${BLUE}🔍 Поиск пользователя...${NC}"
echo ""

if [ -z "$TELEGRAM_ID" ]; then
    # Показать всех пользователей
    echo -e "${YELLOW}Получение списка всех пользователей:${NC}"
    echo ""
    
    USERS=$(curl -s "${API_URL}/users" 2>/dev/null)
    
    if [ -z "$USERS" ] || echo "$USERS" | grep -q "Cannot GET"; then
        echo -e "${RED}❌ Не удалось подключиться к API${NC}"
        echo "Проверьте что backend запущен: sudo systemctl status vpn-backend"
        exit 1
    fi
    
    # Используем Python для парсинга JSON если доступен
    if command -v python3 > /dev/null 2>&1; then
        echo "$USERS" | python3 -c "
import sys, json
try:
    users = json.load(sys.stdin)
    if isinstance(users, list):
        print(f'{CYAN}{'ID':<38} {'Telegram ID':<15} {'Username':<20} {'Status':<10} {'Expire At'}{NC}')
        print('=' * 100)
        for u in users:
            user_id = u.get('id', '')[:36]
            telegram_id = u.get('telegramId', '')
            username = u.get('username', 'N/A')[:20]
            status = u.get('status', 'N/A')
            expire_at = u.get('expireAt', 'N/A')
            if expire_at != 'N/A' and expire_at:
                from datetime import datetime
                try:
                    expire_at = datetime.fromisoformat(expire_at.replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M')
                except:
                    pass
            print(f'{user_id:<38} {telegram_id:<15} {username:<20} {status:<10} {expire_at}')
    else:
        print(json.dumps(users, indent=2, ensure_ascii=False))
except Exception as e:
    print(f'Error: {e}')
    print(users)
" 2>/dev/null || echo "$USERS"
    else
        echo "$USERS"
    fi
    
    echo ""
    echo -e "${YELLOW}Использование для получения конкретного пользователя:${NC}"
    echo "  bash get-user-id.sh TELEGRAM_ID"
    echo ""
    echo -e "${YELLOW}Или через API напрямую:${NC}"
    echo "  curl ${API_URL}/users/telegram/TELEGRAM_ID"
    exit 0
fi

# Поиск по Telegram ID
echo -e "${YELLOW}Ищем пользователя с Telegram ID: $TELEGRAM_ID${NC}"
echo ""

USER=$(curl -s "${API_URL}/users/telegram/${TELEGRAM_ID}" 2>/dev/null)

if [ -z "$USER" ] || echo "$USER" | grep -q "Cannot GET\|404"; then
    echo -e "${RED}❌ Пользователь не найден${NC}"
    echo ""
    echo -e "${YELLOW}Попробуйте:${NC}"
    echo "  1. Проверить правильность Telegram ID"
    echo "  2. Посмотреть всех пользователей: bash get-user-id.sh"
    exit 1
fi

# Используем Python для парсинга JSON если доступен
if command -v python3 > /dev/null 2>&1; then
    USER_ID=$(echo "$USER" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null)
    
    if [ -n "$USER_ID" ]; then
        echo -e "${GREEN}✓ Пользователь найден!${NC}"
        echo ""
        echo -e "${CYAN}User ID:${NC} ${GREEN}${USER_ID}${NC}"
        echo ""
        echo -e "${BLUE}Полная информация:${NC}"
        echo "$USER" | python3 -m json.tool 2>/dev/null || echo "$USER"
    else
        echo "$USER"
    fi
else
    # Простой поиск ID в JSON
    USER_ID=$(echo "$USER" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -n "$USER_ID" ]; then
        echo -e "${GREEN}✓ Пользователь найден!${NC}"
        echo ""
        echo -e "${CYAN}User ID:${NC} ${GREEN}${USER_ID}${NC}"
        echo ""
        echo -e "${BLUE}Полная информация:${NC}"
        echo "$USER"
    else
        echo "$USER"
    fi
fi

echo ""
echo -e "${YELLOW}Полезные команды:${NC}"
echo "  # Получить конфигурацию пользователя"
echo "  bash test-vpn-config.sh ${API_URL} ${USER_ID:-USER_ID_HERE}"
echo ""
echo "  # Диагностика VPN для пользователя"
echo "  bash diagnose-ru-vpn.sh ${API_URL} ${USER_ID:-USER_ID_HERE}"
echo ""
echo "  # Сбросить trial пользователя"
echo "  curl -X POST ${API_URL}/users/${USER_ID:-USER_ID_HERE}/reset-trial"

