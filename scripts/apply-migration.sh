#!/bin/bash

# Скрипт для применения миграции базы данных
# Использование: bash scripts/apply-migration.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔧 Применение миграции базы данных...${NC}"

cd /opt/vpn-service/backend

# Проверяем что мы в правильной директории
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ Ошибка: package.json не найден. Убедитесь что вы в директории backend${NC}"
    exit 1
fi

# Применяем миграцию
echo -e "${YELLOW}📦 Запуск миграции...${NC}"
npm run migration:run

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
    echo -e "${YELLOW}💡 Альтернатива: Выполните SQL напрямую:${NC}"
    echo ""
    echo "psql -U vpn_user -d vpn_service << EOF"
    echo "ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS ping INTEGER;"
    echo "ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS \"lastHealthCheck\" TIMESTAMP;"
    echo "ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS \"isHealthy\" BOOLEAN DEFAULT true;"
    echo "ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 100;"
    echo "ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS region VARCHAR;"
    echo "EOF"
    exit 1
fi

