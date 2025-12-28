#!/bin/bash

# Скрипт для применения миграции через SQL напрямую
# Использование: bash scripts/apply-migration-sql.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔧 Применение миграции через SQL...${NC}"

cd /opt/vpn-service/backend

# Загружаем переменные окружения
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Проверяем переменные
if [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_DATABASE" ]; then
    echo -e "${RED}❌ Ошибка: DB_USERNAME, DB_PASSWORD или DB_DATABASE не установлены в .env${NC}"
    exit 1
fi

# Применяем SQL миграцию
echo -e "${YELLOW}📦 Добавление полей в таблицу vpn_servers...${NC}"

PGPASSWORD="$DB_PASSWORD" psql -h "${DB_HOST:-localhost}" -U "$DB_USERNAME" -d "$DB_DATABASE" << EOF
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS ping INTEGER;
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS "lastHealthCheck" TIMESTAMP;
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS "isHealthy" BOOLEAN DEFAULT true;
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 100;
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS region VARCHAR;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Миграция успешно применена!${NC}"
    echo ""
    echo -e "${YELLOW}🔄 Перезапустите backend:${NC}"
    echo "  sudo systemctl restart vpn-backend"
    echo ""
    echo -e "${YELLOW}🧪 Проверьте что поля добавлены:${NC}"
    echo "  curl http://localhost:3000/wireguard/servers | jq '.[0] | {name, priority, region, isHealthy}'"
else
    echo -e "${RED}❌ Ошибка при применении миграции${NC}"
    exit 1
fi

