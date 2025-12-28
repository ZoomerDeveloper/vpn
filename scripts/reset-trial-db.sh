#!/bin/bash

# Скрипт для сброса trial статуса пользователя через PostgreSQL
# Использование: ./reset-trial-db.sh [TELEGRAM_ID] [DB_USER] [DB_PASSWORD]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TELEGRAM_ID="${1}"
DB_USER="${2:-vpn_user}"
DB_PASSWORD="${3}"

if [ -z "$TELEGRAM_ID" ]; then
    echo -e "${YELLOW}Использование: ./reset-trial-db.sh TELEGRAM_ID [DB_USER] [DB_PASSWORD]${NC}"
    echo "Пример: ./reset-trial-db.sh 123456789"
    exit 1
fi

if [ -z "$DB_PASSWORD" ]; then
    echo -e "${YELLOW}Введите пароль для PostgreSQL пользователя $DB_USER:${NC}"
    read -s DB_PASSWORD
    echo
fi

echo -e "${GREEN}🔄 Сбрасываю trial статус для пользователя: $TELEGRAM_ID${NC}"

# Выполняем SQL запрос
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d vpn_service -c "
UPDATE users 
SET \"trialUsed\" = false, 
    \"trialStartedAt\" = NULL, 
    \"trialExpiresAt\" = NULL,
    \"status\" = 'trial'
WHERE \"telegramId\" = '$TELEGRAM_ID';
" 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Trial статус сброшен!${NC}"
    echo -e "${GREEN}Теперь пользователь может снова использовать /trial${NC}"
else
    echo -e "${RED}❌ Ошибка при сбросе trial статуса${NC}"
    exit 1
fi

