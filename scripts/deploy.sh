#!/bin/bash

# Скрипт для полного деплоя на сервер
# Использование: ./deploy.sh [IP] [USER] [REPO_URL]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVER_IP="${1:-199.247.7.185}"
SERVER_USER="${2:-root}"
REPO_URL="${3}"
SSH_PASS="${SSHPASS}"

if [ -z "$SSH_PASS" ]; then
    echo -e "${YELLOW}Введите SSH пароль для $SERVER_USER@$SERVER_IP:${NC}"
    read -s SSH_PASS
    export SSHPASS="$SSH_PASS"
    echo
fi

if [ -z "$REPO_URL" ]; then
    echo -e "${YELLOW}Введите URL репозитория (или оставьте пустым для пропуска клонирования):${NC}"
    read REPO_URL
fi

remote_exec() {
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$SERVER_USER@$SERVER_IP" "$@"
}

remote_copy() {
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$1" "$SERVER_USER@$SERVER_IP:$2"
}

echo -e "${BLUE}🚀 Начинаю деплой на $SERVER_USER@$SERVER_IP...${NC}"

# Шаг 1: Базовая настройка
if [ ! -z "$1" ] && [ "$1" != "--skip-setup" ]; then
    echo -e "${GREEN}📦 Выполняю базовую настройку сервера...${NC}"
    ./setup-server.sh "$SERVER_IP" "$SERVER_USER" "$SSH_PASS" || true
fi

# Шаг 2: Клонирование репозитория
if [ ! -z "$REPO_URL" ]; then
    echo -e "${GREEN}📥 Клонирую репозиторий...${NC}"
    remote_exec "cd /opt && rm -rf vpn-service && git clone $REPO_URL vpn-service"
fi

# Шаг 3: Установка зависимостей
echo -e "${GREEN}📦 Устанавливаю зависимости Backend...${NC}"
remote_exec "cd /opt/vpn-service/backend && npm install"

echo -e "${GREEN}📦 Устанавливаю зависимости Bot...${NC}"
remote_exec "cd /opt/vpn-service/bot && npm install"

echo -e "${GREEN}📦 Устанавливаю зависимости Scripts...${NC}"
remote_exec "cd /opt/vpn-service/scripts && npm install 2>/dev/null || true"

echo -e "${GREEN}🔨 Собираю Backend...${NC}"
remote_exec "cd /opt/vpn-service/backend && npm run build"

echo -e "${GREEN}🔨 Собираю Bot...${NC}"
remote_exec "cd /opt/vpn-service/bot && npm run build"

echo -e "${YELLOW}⚠️  ВАЖНО:${NC}"
echo -e "${YELLOW}Теперь нужно:${NC}"
echo "1. Настроить .env файлы на сервере"
echo "2. Запустить миграции БД"
echo "3. Заполнить seed данные"
echo "4. Настроить systemd services"
echo ""
echo -e "${GREEN}Для подключения к серверу:${NC}"
echo "ssh $SERVER_USER@$SERVER_IP"
echo ""
echo -e "${GREEN}Директория проекта: /opt/vpn-service${NC}"

