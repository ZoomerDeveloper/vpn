#!/bin/bash

# Скрипт для установки MTU = 1280 на WireGuard сервере
# Использование: bash fix-server-mtu.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_CONFIG="/etc/wireguard/${WG_INTERFACE}.conf"
MTU_VALUE="${MTU_VALUE:-1280}"

echo -e "${BLUE}🔧 Установка MTU = ${MTU_VALUE} на WireGuard сервере...${NC}"
echo ""

# Проверяем что файл существует
if [ ! -f "$WG_CONFIG" ]; then
    echo -e "${RED}❌ Файл конфигурации не найден: $WG_CONFIG${NC}"
    exit 1
fi

# Делаем бэкап
BACKUP_FILE="${WG_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$WG_CONFIG" "$BACKUP_FILE"
echo -e "${GREEN}✓ Бэкап создан: $BACKUP_FILE${NC}"

# Проверяем есть ли уже MTU в конфиге
if grep -q "^MTU" "$WG_CONFIG"; then
    echo -e "${YELLOW}⚠️  MTU уже задан в конфиге, обновляю...${NC}"
    # Обновляем существующую строку MTU
    sed -i "s/^MTU = .*/MTU = ${MTU_VALUE}/" "$WG_CONFIG"
else
    echo -e "${YELLOW}Добавляю MTU = ${MTU_VALUE} в [Interface]...${NC}"
    # Добавляем MTU после строки [Interface] или после Address/ListenPort/PrivateKey
    # Ищем секцию [Interface] и добавляем MTU после последнего параметра в этой секции
    if grep -q "^\[Interface\]" "$WG_CONFIG"; then
        # Находим строку с [Interface] и добавляем MTU после PrivateKey или ListenPort
        if grep -q "PrivateKey" "$WG_CONFIG"; then
            sed -i "/^PrivateKey/a MTU = ${MTU_VALUE}" "$WG_CONFIG"
        elif grep -q "ListenPort" "$WG_CONFIG"; then
            sed -i "/^ListenPort/a MTU = ${MTU_VALUE}" "$WG_CONFIG"
        else
            # Если нет PrivateKey/ListenPort, добавляем после [Interface]
            sed -i "/^\[Interface\]/a MTU = ${MTU_VALUE}" "$WG_CONFIG"
        fi
    else
        echo -e "${RED}❌ Секция [Interface] не найдена в конфиге${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ MTU добавлен в конфигурацию${NC}"
echo ""

# Показываем изменения
echo -e "${BLUE}Проверка конфигурации:${NC}"
grep -A 5 "^\[Interface\]" "$WG_CONFIG" | head -6
echo ""

# Применяем изменения (перезапускаем WireGuard)
echo -e "${YELLOW}Перезапуск WireGuard...${NC}"
systemctl restart wg-quick@${WG_INTERFACE}

# Ждем немного
sleep 2

# Проверяем что WireGuard запущен
if systemctl is-active --quiet wg-quick@${WG_INTERFACE}; then
    echo -e "${GREEN}✓ WireGuard перезапущен${NC}"
else
    echo -e "${RED}❌ Ошибка при перезапуске WireGuard${NC}"
    echo -e "${YELLOW}Восстанавливаю бэкап...${NC}"
    cp "$BACKUP_FILE" "$WG_CONFIG"
    systemctl restart wg-quick@${WG_INTERFACE}
    exit 1
fi

# Проверяем что MTU применился
echo ""
echo -e "${BLUE}Проверка MTU на интерфейсе:${NC}"
if ip link show "$WG_INTERFACE" | grep -q "mtu ${MTU_VALUE}"; then
    echo -e "${GREEN}✓ MTU = ${MTU_VALUE} успешно применён${NC}"
    ip link show "$WG_INTERFACE" | grep -i mtu
else
    echo -e "${YELLOW}⚠️  MTU может быть не применён автоматически${NC}"
    echo -e "${YELLOW}Проверьте вручную: ip link show $WG_INTERFACE${NC}"
    ip link show "$WG_INTERFACE" | grep -i mtu || true
fi

echo ""
echo -e "${GREEN}✅ Готово!${NC}"
echo ""
echo -e "${YELLOW}⚠️  ВАЖНО: Все клиентские конфиги нужно пересоздать с MTU = ${MTU_VALUE}${NC}"
echo -e "${YELLOW}Старые конфиги без MTU не будут работать правильно в РФ${NC}"

