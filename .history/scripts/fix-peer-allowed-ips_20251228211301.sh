#!/bin/bash

# Скрипт для исправления missing allowed-ips у WireGuard peer'ов
# Использование: bash fix-peer-allowed-ips.sh [PUBLIC_KEY] [ALLOCATED_IP]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PUBLIC_KEY="$1"
ALLOCATED_IP="$2"

if [ -z "$PUBLIC_KEY" ]; then
    echo -e "${RED}❌ Ошибка: Не указан public key${NC}"
    echo -e "${YELLOW}Использование: bash fix-peer-allowed-ips.sh PUBLIC_KEY [ALLOCATED_IP]${NC}"
    echo ""
    echo "Пример: bash fix-peer-allowed-ips.sh 5qqjkBgqS70lLDQEmsYsctdJfchSUeEdxGHUpnq5UlU= 10.0.0.34/32"
    echo ""
    echo "Или для автоматического поиска и исправления всех peer'ов с проблемой:"
    echo "  bash fix-peer-allowed-ips.sh"
    exit 1
fi

WG_INTERFACE="${WG_INTERFACE:-wg0}"

# Если не указан ALLOCATED_IP, пробуем получить из WireGuard статуса
if [ -z "$ALLOCATED_IP" ]; then
    echo -e "${YELLOW}Получение allocated IP из базы данных...${NC}"
    
    # Пробуем получить из базы данных по public key
    ALLOCATED_IP_DB=$(sudo -u postgres psql -d vpn_service -t -c "
        SELECT \"allocatedIp\" FROM vpn_peers WHERE \"publicKey\" = '$PUBLIC_KEY' AND \"isActive\" = true LIMIT 1;
    " 2>/dev/null | xargs)
    
    if [ -n "$ALLOCATED_IP_DB" ]; then
        ALLOCATED_IP="$ALLOCATED_IP_DB"
        echo -e "${GREEN}✓ Найден IP в БД: $ALLOCATED_IP${NC}"
    else
        echo -e "${RED}❌ Не удалось найти allocated IP в БД${NC}"
        echo -e "${YELLOW}Пожалуйста, укажите allocated IP вручную${NC}"
        exit 1
    fi
fi

# Убеждаемся что IP содержит /32
if [[ ! "$ALLOCATED_IP" == *"/32" ]]; then
    ALLOCATED_IP="${ALLOCATED_IP}/32"
fi

echo -e "${BLUE}🔧 Исправление allowed-ips для peer...${NC}"
echo -e "Public Key: ${PUBLIC_KEY:0:20}..."
echo -e "Allowed IPs: $ALLOCATED_IP"
echo ""

# Проверяем текущий статус
echo -e "${YELLOW}Текущий статус peer'а:${NC}"
sudo wg show "$WG_INTERFACE" | grep -A 10 "$PUBLIC_KEY" || echo "Peer не найден"
echo ""

# Удаляем peer и добавляем заново с правильными allowed-ips
echo -e "${YELLOW}Исправление конфигурации...${NC}"

# Удаляем peer
sudo wg set "$WG_INTERFACE" peer "$PUBLIC_KEY" remove 2>&1 || echo "Peer не был добавлен или уже удален"

# Добавляем peer с правильными allowed-ips
sudo wg set "$WG_INTERFACE" peer "$PUBLIC_KEY" allowed-ips "$ALLOCATED_IP" 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Peer успешно исправлен${NC}"
    
    # Проверяем результат
    echo ""
    echo -e "${YELLOW}Новый статус peer'а:${NC}"
    sudo wg show "$WG_INTERFACE" | grep -A 10 "$PUBLIC_KEY"
    
    echo ""
    echo -e "${GREEN}✅ Исправление завершено!${NC}"
else
    echo -e "${RED}❌ Ошибка при исправлении peer'а${NC}"
    exit 1
fi

