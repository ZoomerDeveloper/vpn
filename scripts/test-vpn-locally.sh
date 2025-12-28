#!/bin/bash

# Скрипт для тестирования VPN локально (без реального пользователя в РФ)
# Использование: bash test-vpn-locally.sh [USER_ID]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

API_URL="${1:-http://localhost:3000}"
USER_ID="${2}"

echo -e "${BLUE}🧪 Тестирование VPN локально...${NC}"
echo ""

if [ -z "$USER_ID" ]; then
    echo -e "${YELLOW}Использование: bash test-vpn-locally.sh [API_URL] USER_ID${NC}"
    echo "Пример: bash test-vpn-locally.sh http://localhost:3000 USER_ID"
    exit 1
fi

# 1. Получаем конфигурацию
echo -e "${YELLOW}1. Получение конфигурации...${NC}"
PEERS=$(curl -s "${API_URL}/vpn/users/${USER_ID}/peers" 2>/dev/null)

PEER_ID=$(echo "$PEERS" | python3 -c "
import sys, json
try:
    peers = json.load(sys.stdin)
    if isinstance(peers, list):
        for p in peers:
            if p.get('isActive'):
                print(p['id'])
                break
except:
    pass
" 2>/dev/null)

if [ -z "$PEER_ID" ]; then
    echo -e "${RED}❌ Нет активных peer'ов${NC}"
    exit 1
fi

CONFIG_RESPONSE=$(curl -s "${API_URL}/vpn/peers/${PEER_ID}/config" 2>/dev/null)
CONFIG=$(echo "$CONFIG_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('config', ''))
except:
    pass
" 2>/dev/null)

if [ -z "$CONFIG" ]; then
    echo -e "${RED}❌ Не удалось получить конфигурацию${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Конфигурация получена${NC}"
echo ""

# 2. Сохраняем конфигурацию во временный файл
TEMP_CONFIG="/tmp/test-vpn-${PEER_ID:0:8}.conf"
echo "$CONFIG" > "$TEMP_CONFIG"
echo -e "${CYAN}Конфигурация сохранена в: ${TEMP_CONFIG}${NC}"
echo ""

# 3. Проверяем структуру конфигурации
echo -e "${YELLOW}2. Проверка структуры конфигурации:${NC}"

HAS_INTERFACE=$(grep -c "^\[Interface\]" "$TEMP_CONFIG" || echo "0")
HAS_PEER=$(grep -c "^\[Peer\]" "$TEMP_CONFIG" || echo "0")
HAS_PRIVATE_KEY=$(grep -c "^PrivateKey = " "$TEMP_CONFIG" || echo "0")
HAS_ADDRESS=$(grep -c "^Address = " "$TEMP_CONFIG" || echo "0")
HAS_DNS=$(grep -c "^DNS = " "$TEMP_CONFIG" || echo "0")
HAS_ENDPOINT=$(grep -c "^Endpoint = " "$TEMP_CONFIG" || echo "0")
HAS_ALLOWED_IPS=$(grep -c "^AllowedIPs = " "$TEMP_CONFIG" || echo "0")

echo "  [Interface]: $([ $HAS_INTERFACE -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  PrivateKey: $([ $HAS_PRIVATE_KEY -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  Address: $([ $HAS_ADDRESS -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  DNS: $([ $HAS_DNS -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  [Peer]: $([ $HAS_PEER -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  PublicKey: $([ $HAS_PEER -gt 0 ] && grep -q "^PublicKey" "$TEMP_CONFIG" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  Endpoint: $([ $HAS_ENDPOINT -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"
echo "  AllowedIPs: $([ $HAS_ALLOWED_IPS -gt 0 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}❌${NC}")"

# 4. Извлекаем параметры для проверки
ENDPOINT=$(grep "^Endpoint = " "$TEMP_CONFIG" | cut -d'=' -f2 | xargs || echo "")
ENDPOINT_IP=$(echo "$ENDPOINT" | cut -d':' -f1)
ENDPOINT_PORT=$(echo "$ENDPOINT" | cut -d':' -f2)
DNS_VALUE=$(grep "^DNS = " "$TEMP_CONFIG" | cut -d'=' -f2 | xargs || echo "")
ALLOWED_IPS=$(grep "^AllowedIPs = " "$TEMP_CONFIG" | cut -d'=' -f2 | xargs || echo "")
ADDRESS=$(grep "^Address = " "$TEMP_CONFIG" | cut -d'=' -f2 | xargs || echo "")

echo ""
echo -e "${YELLOW}3. Проверка параметров:${NC}"
echo -e "  Endpoint: ${CYAN}${ENDPOINT}${NC}"
echo -e "  DNS: ${CYAN}${DNS_VALUE}${NC}"
echo -e "  AllowedIPs: ${CYAN}${ALLOWED_IPS}${NC}"
echo -e "  Address: ${CYAN}${ADDRESS}${NC}"

# 5. Проверяем доступность endpoint
echo ""
echo -e "${YELLOW}4. Проверка доступности endpoint:${NC}"
if [ -n "$ENDPOINT_IP" ] && [ -n "$ENDPOINT_PORT" ]; then
    # Проверка через nc (netcat)
    if command -v nc > /dev/null 2>&1; then
        if timeout 3 nc -uz "$ENDPOINT_IP" "$ENDPOINT_PORT" 2>/dev/null; then
            echo -e "  ${GREEN}✓ Порт ${ENDPOINT_PORT}/UDP доступен${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Порт ${ENDPOINT_PORT}/UDP недоступен (возможно закрыт firewall)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  nc (netcat) не установлен, пропускаю проверку порта${NC}"
    fi
    
    # Проверка ping
    if ping -c 2 -W 2 "$ENDPOINT_IP" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ IP адрес ${ENDPOINT_IP} доступен (ping)${NC}"
    else
        echo -e "  ${YELLOW}⚠️  IP адрес ${ENDPOINT_IP} не отвечает на ping (это нормально)${NC}"
    fi
fi

# 6. Проверяем DNS серверы
echo ""
echo -e "${YELLOW}5. Проверка DNS серверов:${NC}"
if [ -n "$DNS_VALUE" ]; then
    IFS=',' read -ra DNS_ARRAY <<< "$DNS_VALUE"
    for dns in "${DNS_ARRAY[@]}"; do
        dns=$(echo "$dns" | xargs)
        if dig @$dns google.com +short +timeout=2 > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓ ${dns} работает${NC}"
        else
            echo -e "  ${RED}❌ ${dns} не отвечает${NC}"
        fi
    done
fi

# 7. Проверяем peer на WireGuard сервере
echo ""
echo -e "${YELLOW}6. Проверка peer на WireGuard сервере:${NC}"
if systemctl is-active --quiet wg-quick@wg0 2>/dev/null; then
    PUBLIC_KEY=$(echo "$PEERS" | python3 -c "
import sys, json
try:
    peers = json.load(sys.stdin)
    if isinstance(peers, list):
        for p in peers:
            if p.get('isActive'):
                print(p.get('publicKey', ''))
                break
except:
    pass
" 2>/dev/null)
    
    if [ -n "$PUBLIC_KEY" ]; then
        WG_OUTPUT=$(wg show wg0 2>/dev/null | grep -A 5 "peer: ${PUBLIC_KEY}" || echo "")
        if [ -n "$WG_OUTPUT" ]; then
            echo -e "  ${GREEN}✓ Peer найден на сервере${NC}"
            HANDSHAKE=$(echo "$WG_OUTPUT" | grep "latest handshake" || echo "")
            if [ -n "$HANDSHAKE" ]; then
                echo -e "  ${CYAN}  ${HANDSHAKE}${NC}"
            else
                echo -e "  ${YELLOW}  ⚠️  Handshake отсутствует (peer не подключен)${NC}"
            fi
        else
            echo -e "  ${RED}❌ Peer не найден на сервере${NC}"
        fi
    fi
else
    echo -e "  ${YELLOW}⚠️  WireGuard не запущен или недоступен${NC}"
fi

# 8. Валидация конфигурации через wg-quick (если доступно)
echo ""
echo -e "${YELLOW}7. Валидация конфигурации:${NC}"
if command -v wg-quick > /dev/null 2>&1; then
    # Проверяем синтаксис (не поднимаем интерфейс)
    if wg-quick strip "$TEMP_CONFIG" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Синтаксис конфигурации правильный${NC}"
    else
        echo -e "  ${RED}❌ Ошибка в синтаксисе конфигурации${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  wg-quick не установлен, пропускаю валидацию${NC}"
fi

# 9. Вывод конфигурации для ручной проверки
echo ""
echo -e "${YELLOW}8. Конфигурация для проверки:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cat "$TEMP_CONFIG"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 10. Рекомендации
echo -e "${YELLOW}9. Рекомендации для тестирования:${NC}"
echo ""
echo -e "${CYAN}Локальное тестирование (на сервере):${NC}"
echo "  1. Конфигурация сохранена в: ${TEMP_CONFIG}"
echo "  2. Можно попробовать подключиться с сервера (если WireGuard установлен):"
echo "     sudo wg-quick up ${TEMP_CONFIG}"
echo "  3. Проверить подключение:"
echo "     curl ifconfig.me"
echo "     dig @1.1.1.1 google.com"
echo ""
echo -e "${CYAN}Тестирование с другого устройства:${NC}"
echo "  1. Скопируйте конфигурацию:"
echo "     cat ${TEMP_CONFIG}"
echo "  2. Импортируйте в WireGuard приложение"
echo "  3. Подключитесь и проверьте:"
echo "     - IP адрес (должен быть IP сервера)"
echo "     - DNS резолвинг"
echo "     - Доступность сайтов"
echo ""
echo -e "${CYAN}Проверка доступности порта извне:${NC}"
echo "  Используйте онлайн-сервисы:"
echo "  - https://www.yougetsignal.com/tools/open-ports/"
echo "  - https://portchecker.co/"
echo "  Проверьте порт ${ENDPOINT_PORT}/UDP"
echo ""

# Оставляем файл для ручной проверки
echo -e "${GREEN}✓ Тестирование завершено${NC}"
echo -e "${YELLOW}Конфигурация сохранена в: ${TEMP_CONFIG}${NC}"
echo -e "${YELLOW}Удалить после тестирования: rm ${TEMP_CONFIG}${NC}"

