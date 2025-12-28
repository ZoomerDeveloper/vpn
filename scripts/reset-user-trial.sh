#!/bin/bash

# Скрипт для сброса trial статуса пользователя (для тестирования)
# Использование: ./reset-user-trial.sh [API_URL] [TELEGRAM_ID]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

API_URL="${1:-http://localhost:3000}"
TELEGRAM_ID="${2}"

if [ -z "$TELEGRAM_ID" ]; then
    echo -e "${YELLOW}Использование: ./reset-user-trial.sh [API_URL] TELEGRAM_ID${NC}"
    echo "Пример: ./reset-user-trial.sh http://localhost:3000 123456789"
    exit 1
fi

echo -e "${GREEN}🔍 Ищу пользователя с Telegram ID: $TELEGRAM_ID...${NC}"

# Получаем информацию о пользователе
USER_RESPONSE=$(curl -s "${API_URL}/users/telegram/${TELEGRAM_ID}")

if echo "$USER_RESPONSE" | grep -q "not found\|404"; then
    echo -e "${RED}❌ Пользователь не найден${NC}"
    exit 1
fi

USER_ID=$(echo "$USER_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
    echo -e "${RED}❌ Не удалось получить ID пользователя${NC}"
    echo "Ответ API:"
    echo "$USER_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Пользователь найден: $USER_ID${NC}"

echo -e "${YELLOW}🔄 Сбрасываю trial статус...${NC}"

# Сбрасываем trial через API
RESPONSE=$(curl -s -X POST "${API_URL}/users/${USER_ID}/reset-trial")

if echo "$RESPONSE" | grep -q "\"id\""; then
    echo -e "${GREEN}✅ Trial статус успешно сброшен!${NC}"
    echo -e "${GREEN}Теперь пользователь может снова использовать /trial${NC}"
else
    echo -e "${RED}❌ Ошибка при сбросе trial:${NC}"
    echo "$RESPONSE" | head -20
    echo ""
    echo -e "${YELLOW}Альтернативный способ - через PostgreSQL:${NC}"
    echo "Используйте скрипт: bash scripts/reset-trial-db.sh $TELEGRAM_ID"
    exit 1
fi

