#!/bin/bash

# Скрипт для автоматической настройки сервера через SSH
# Использование: ./setup-server.sh [IP] [USER] [PASSWORD]
# Или: SSHPASS='password' ./setup-server.sh [IP] [USER]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Параметры
SERVER_IP="${1:-199.247.7.185}"
SERVER_USER="${2:-root}"
SSH_PASS="${3:-$SSHPASS}"

if [ -z "$SSH_PASS" ]; then
    echo -e "${YELLOW}Введите пароль для $SERVER_USER@$SERVER_IP:${NC}"
    read -s SSH_PASS
    echo
fi

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}sshpass не установлен. Установите его:${NC}"
    echo "  macOS: brew install hudochenkov/sshpass/sshpass"
    echo "  Ubuntu/Debian: sudo apt install sshpass"
    exit 1
fi

echo -e "${GREEN}🚀 Начинаю настройку сервера $SERVER_USER@$SERVER_IP...${NC}"

# Функция для выполнения команд на удаленном сервере
remote_exec() {
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$SERVER_USER@$SERVER_IP" "$@"
}

# Функция для копирования файлов
remote_copy() {
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$1" "$SERVER_USER@$SERVER_IP:$2"
}

echo -e "${GREEN}📦 Обновляю систему...${NC}"
remote_exec "apt update && apt upgrade -y"

echo -e "${GREEN}📦 Устанавливаю базовые пакеты...${NC}"
remote_exec "apt install -y curl wget git build-essential ufw"

echo -e "${GREEN}🐘 Устанавливаю PostgreSQL...${NC}"
remote_exec "apt install -y postgresql postgresql-contrib"

echo -e "${GREEN}📦 Устанавливаю Node.js 18...${NC}"
remote_exec "curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt install -y nodejs"

echo -e "${GREEN}🔐 Устанавливаю WireGuard...${NC}"
remote_exec "apt install -y wireguard wireguard-tools qrencode iptables"

echo -e "${GREEN}🔧 Настраиваю IP forwarding...${NC}"
remote_exec "echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf"
remote_exec "echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf"
remote_exec "sysctl -p"

echo -e "${GREEN}🔥 Настраиваю firewall...${NC}"
remote_exec "ufw --force enable"
remote_exec "ufw allow 22/tcp"
remote_exec "ufw allow 3000/tcp"
remote_exec "ufw allow 51820/udp"
remote_exec "ufw allow 80/tcp"
remote_exec "ufw allow 443/tcp"

echo -e "${GREEN}👤 Создаю пользователя vpn (если не существует)...${NC}"
# Создаем пользователя без пароля (можно войти только через sudo/su)
remote_exec "if ! id 'vpn' &>/dev/null; then useradd -m -s /bin/bash vpn && usermod -aG sudo vpn && passwd -d vpn 2>/dev/null || true; fi"
echo -e "${YELLOW}ℹ️  Пользователь vpn создан без пароля (для входа используйте sudo/su от root)${NC}"

echo -e "${GREEN}📁 Создаю директорию для проекта...${NC}"
remote_exec "mkdir -p /opt/vpn-service && chown vpn:vpn /opt/vpn-service"

echo -e "${GREEN}✅ Базовая настройка сервера завершена!${NC}"
echo ""
echo -e "${GREEN}📊 Информация о сервере:${NC}"
remote_exec "echo 'OS:'; cat /etc/os-release | grep PRETTY_NAME; echo ''; echo 'Node.js:'; node --version; echo ''; echo 'npm:'; npm --version; echo ''; echo 'PostgreSQL:'; psql --version; echo ''; echo 'WireGuard:'; wg --version"

echo ""
echo -e "${GREEN}🎉 Сервер готов к деплою!${NC}"
echo ""
echo -e "${YELLOW}Следующие шаги:${NC}"
echo "1. Настройте PostgreSQL (см. docs/DEPLOY.md)"
echo "2. Склонируйте репозиторий на сервер"
echo "3. Настройте .env файлы"
echo "4. Запустите миграции и seed данные"
echo "5. Настройте systemd services"

echo ""
echo -e "${YELLOW}Для подключения к серверу:${NC}"
echo "ssh $SERVER_USER@$SERVER_IP"

