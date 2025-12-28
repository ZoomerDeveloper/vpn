#!/bin/bash

# Скрипт для проверки статуса WireGuard peer'ов

echo "🔍 Проверка статуса WireGuard peer'ов..."
echo ""

INTERFACE="${WG_INTERFACE:-wg0}"

echo "1. Проверка интерфейса $INTERFACE:"
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "❌ Интерфейс $INTERFACE не найден"
    exit 1
fi
echo "✓ Интерфейс существует"
echo ""

echo "2. Статус WireGuard (wg show $INTERFACE):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
wg show "$INTERFACE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "3. Статус интерфейса:"
if systemctl is-active --quiet "wg-quick@${INTERFACE}" 2>/dev/null; then
    echo "✓ WireGuard сервис активен"
else
    echo "⚠️  WireGuard сервис не активен (но интерфейс может быть поднят)"
fi
echo ""

echo "4. Подключенные peer'ы (с handshake менее 3 минут):"
wg show "$INTERFACE" | grep -A 5 "peer:" | while IFS= read -r line; do
    if echo "$line" | grep -q "peer:"; then
        PUBLIC_KEY=$(echo "$line" | sed 's/peer: //')
        echo ""
        echo "Peer: ${PUBLIC_KEY:0:16}..."
    elif echo "$line" | grep -q "latest handshake:"; then
        HANDSHAKE=$(echo "$line" | sed 's/latest handshake: //')
        echo "  Handshake: $HANDSHAKE"
        
        # Проверяем возраст handshake
        if echo "$HANDSHAKE" | grep -qE "(day|week|month|hour)"; then
            echo "  Статус: ❌ Не подключен (handshake слишком старый)"
        elif echo "$HANDSHAKE" | grep -qE "[0-9]+ minute"; then
            MINUTES=$(echo "$HANDSHAKE" | grep -oE "[0-9]+ minute" | grep -oE "[0-9]+")
            if [ -n "$MINUTES" ] && [ "$MINUTES" -lt 3 ]; then
                echo "  Статус: ✅ Подключен (handshake ${MINUTES} минуты назад)"
            else
                echo "  Статус: ❌ Не подключен (handshake ${MINUTES} минут назад)"
            fi
        else
            echo "  Статус: ✅ Подключен (handshake только что или секунды назад)"
        fi
    elif echo "$line" | grep -q "endpoint:"; then
        ENDPOINT=$(echo "$line" | sed 's/endpoint: //')
        echo "  Endpoint: $ENDPOINT"
    elif echo "$line" | grep -q "transfer:"; then
        TRANSFER=$(echo "$line" | sed 's/transfer: //')
        echo "  Transfer: $TRANSFER"
    fi
done
echo ""

