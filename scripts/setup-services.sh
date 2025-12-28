#!/bin/bash

# Скрипт для создания systemd сервисов для VPN Service
# Использование: bash setup-services.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔧 Создаю systemd сервисы...${NC}"

# Backend service
echo -e "${YELLOW}Создаю vpn-backend.service...${NC}"
sudo tee /etc/systemd/system/vpn-backend.service > /dev/null <<EOF
[Unit]
Description=VPN Service Backend API
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vpn-service/backend
ExecStart=/usr/bin/node dist/main.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# Bot service
echo -e "${YELLOW}Создаю vpn-bot.service...${NC}"
sudo tee /etc/systemd/system/vpn-bot.service > /dev/null <<EOF
[Unit]
Description=VPN Service Telegram Bot
After=network.target vpn-backend.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vpn-service/bot
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓ Сервисы созданы${NC}"

# Перезагружаем systemd
echo -e "${YELLOW}Перезагружаю systemd...${NC}"
sudo systemctl daemon-reload

# Включаем автозапуск
echo -e "${YELLOW}Включаю автозапуск...${NC}"
sudo systemctl enable vpn-backend
sudo systemctl enable vpn-bot

echo -e "${GREEN}✅ Готово!${NC}"
echo ""
echo -e "${GREEN}Теперь можно запустить сервисы:${NC}"
echo "  sudo systemctl start vpn-backend"
echo "  sudo systemctl start vpn-bot"
echo ""
echo -e "${GREEN}Или проверить статус:${NC}"
echo "  sudo systemctl status vpn-backend"
echo "  sudo systemctl status vpn-bot"
echo ""
echo -e "${GREEN}Просмотр логов:${NC}"
echo "  sudo journalctl -u vpn-backend -f"
echo "  sudo journalctl -u vpn-bot -f"

