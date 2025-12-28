#!/bin/bash

# Скрипт для настройки PostgreSQL на сервере
# Использование: ./setup-postgres.sh [IP] [USER] [DB_PASSWORD]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVER_IP="${1:-199.247.7.185}"
SERVER_USER="${2:-root}"
SSH_PASS="${3:-$SSHPASS}"
DB_PASSWORD="${4}"

if [ -z "$SSH_PASS" ]; then
    echo -e "${YELLOW}Введите SSH пароль для $SERVER_USER@$SERVER_IP:${NC}"
    read -s SSH_PASS
    echo
fi

if [ -z "$DB_PASSWORD" ]; then
    echo -e "${YELLOW}Введите пароль для PostgreSQL пользователя vpn_user:${NC}"
    read -s DB_PASSWORD
    echo
fi

remote_exec() {
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$SERVER_USER@$SERVER_IP" "$@"
}

echo -e "${GREEN}🐘 Настраиваю PostgreSQL...${NC}"

# Создаем базу данных и пользователя
remote_exec "sudo -u postgres psql << EOF
-- Создаем базу данных если не существует
SELECT 'CREATE DATABASE vpn_service'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vpn_service')\\gexec

-- Создаем пользователя если не существует
DO \\$\\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'vpn_user') THEN
    CREATE USER vpn_user WITH PASSWORD '$DB_PASSWORD';
  END IF;
END
\\$\\$;

-- Даем права
GRANT ALL PRIVILEGES ON DATABASE vpn_service TO vpn_user;
ALTER DATABASE vpn_service OWNER TO vpn_user;
\\q
EOF"

echo -e "${GREEN}✅ PostgreSQL настроен!${NC}"
echo -e "${GREEN}База данных: vpn_service${NC}"
echo -e "${GREEN}Пользователь: vpn_user${NC}"
echo -e "${GREEN}Пароль: [установлен]${NC}"

