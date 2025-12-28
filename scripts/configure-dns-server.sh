#!/bin/bash

# Скрипт для настройки DNS сервера на VPN сервере для лучшей работы в РФ
# Использование: bash configure-dns-server.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Настройка DNS сервера для VPN (оптимизация для РФ)...${NC}"
echo ""

# Проверяем что мы root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Пожалуйста, запустите скрипт с sudo${NC}"
    exit 1
fi

# Устанавливаем dnsmasq (легкий DNS сервер)
echo -e "${YELLOW}Устанавливаю dnsmasq...${NC}"
apt-get update
apt-get install -y dnsmasq

# Получаем IP адрес WireGuard интерфейса
WG_IP=$(ip addr show wg0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

if [ -z "$WG_IP" ]; then
    echo -e "${RED}❌ WireGuard интерфейс wg0 не найден${NC}"
    exit 1
fi

echo -e "${GREEN}✓ WireGuard IP: $WG_IP${NC}"

# Настраиваем dnsmasq
echo -e "${YELLOW}Настраиваю dnsmasq...${NC}"

# Бэкапим оригинальный конфиг
if [ ! -f /etc/dnsmasq.conf.backup ]; then
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
fi

# Создаем новый конфиг для dnsmasq
cat > /etc/dnsmasq.conf <<EOF
# DNS сервер для VPN клиентов (оптимизирован для РФ)
interface=wg0
bind-interfaces

# Используем надежные upstream DNS серверы
server=1.1.1.1
server=1.0.0.1
server=8.8.8.8
server=8.8.4.4

# Кэширование для ускорения
cache-size=1000
no-negcache

# Логирование (опционально)
# log-queries
# log-facility=/var/log/dnsmasq.log
EOF

# Запускаем dnsmasq
systemctl enable dnsmasq
systemctl restart dnsmasq

echo -e "${GREEN}✓ dnsmasq настроен и запущен${NC}"

# Обновляем DNS в конфиге WireGuard сервера (если нужно)
echo -e "${YELLOW}Обновляю DNS в конфигурации WireGuard...${NC}"
echo -e "${GREEN}✓ DNS сервер настроен: $WG_IP${NC}"

echo ""
echo -e "${BLUE}📋 Следующие шаги:${NC}"
echo "1. Обновите DNS в базе данных для WireGuard сервера:"
echo "   UPDATE vpn_servers SET dns = '$WG_IP' WHERE name = 'server1';"
echo ""
echo "2. Или через API обновите сервер:"
echo "   PATCH /wireguard/servers/:id"
echo "   { \"dns\": \"$WG_IP\" }"
echo ""
echo "3. Пересоздайте конфигурации для существующих клиентов"
echo ""
echo -e "${GREEN}✅ DNS сервер настроен!${NC}"

