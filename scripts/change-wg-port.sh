#!/bin/bash

# Скрипт для изменения порта WireGuard (для обхода блокировок в РФ)
# Использование: bash change-wg-port.sh [NEW_PORT]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NEW_PORT="${1:-443}"
INTERFACE="${WG_INTERFACE:-wg0}"
CONFIG_FILE="/etc/wireguard/${INTERFACE}.conf"

echo -e "${BLUE}🔧 Изменение порта WireGuard...${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Запустите скрипт от root${NC}"
    exit 1
fi

# 1. Проверяем текущий порт
CURRENT_PORT=$(grep "^ListenPort" "$CONFIG_FILE" 2>/dev/null | awk '{print $3}' || echo "не найден")
echo -e "${CYAN}Текущий порт: ${CURRENT_PORT}${NC}"
echo -e "${CYAN}Новый порт: ${NEW_PORT}${NC}"
echo ""

if [ "$CURRENT_PORT" == "$NEW_PORT" ]; then
    echo -e "${YELLOW}⚠️  Порт уже установлен на ${NEW_PORT}${NC}"
    read -p "Продолжить? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# 2. Резервная копия
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✓ Создана резервная копия: ${BACKUP_FILE}${NC}"

# 3. Изменяем порт в конфигурации
sed -i "s/^ListenPort = .*/ListenPort = ${NEW_PORT}/" "$CONFIG_FILE"
echo -e "${GREEN}✓ Порт изменен в ${CONFIG_FILE}${NC}"

# 4. Перезапускаем WireGuard
echo ""
echo -e "${YELLOW}Перезапускаю WireGuard...${NC}"
systemctl restart wg-quick@${INTERFACE}

if systemctl is-active --quiet wg-quick@${INTERFACE}; then
    echo -e "${GREEN}✓ WireGuard перезапущен${NC}"
else
    echo -e "${RED}❌ Ошибка перезапуска WireGuard${NC}"
    echo -e "${YELLOW}Восстанавливаю резервную копию...${NC}"
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    systemctl restart wg-quick@${INTERFACE}
    exit 1
fi

# 5. Проверяем новый порт
ACTUAL_PORT=$(wg show ${INTERFACE} listen-port 2>/dev/null || echo "")
if [ "$ACTUAL_PORT" == "$NEW_PORT" ]; then
    echo -e "${GREEN}✓ WireGuard слушает на порту ${NEW_PORT}${NC}"
else
    echo -e "${YELLOW}⚠️  Проверьте порт вручную: wg show ${INTERFACE}${NC}"
fi

# 6. Обновляем порт в базе данных
echo ""
echo -e "${YELLOW}Обновляю порт в базе данных...${NC}"
sudo -u postgres psql -d vpn_service -c "UPDATE vpn_servers SET port = ${NEW_PORT};" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Порт обновлен в базе данных${NC}"
else
    echo -e "${YELLOW}⚠️  Не удалось обновить порт в БД (проверьте вручную)${NC}"
fi

# 7. Открываем порт в firewall (если используется ufw)
if command -v ufw > /dev/null 2>&1; then
    echo ""
    read -p "Открыть порт ${NEW_PORT}/udp в ufw? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ufw allow ${NEW_PORT}/udp
        echo -e "${GREEN}✓ Порт ${NEW_PORT}/udp открыт в firewall${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✓ Порт WireGuard изменен на ${NEW_PORT}${NC}"
echo ""
echo -e "${YELLOW}⚠️  ВАЖНО:${NC}"
echo "  Пользователям нужно получить НОВУЮ конфигурацию с новым портом!"
echo ""
echo -e "${CYAN}Для пересоздания конфигурации пользователя:${NC}"
echo "  bash recreate-user-config.sh USER_ID"

