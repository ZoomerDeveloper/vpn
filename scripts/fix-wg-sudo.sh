#!/bin/bash

# Скрипт для настройки sudo без пароля для команды wg
# Использование: sudo bash fix-wg-sudo.sh [USERNAME]

USER="${1:-vpn}"

if [ "$EUID" -ne 0 ]; then 
    echo "❌ Запустите скрипт с sudo: sudo bash fix-wg-sudo.sh"
    exit 1
fi

echo "🔧 Настройка sudo без пароля для команды 'wg' для пользователя $USER..."

# Проверяем существует ли пользователь
if ! id "$USER" &>/dev/null; then
    echo "❌ Пользователь $USER не существует"
    exit 1
fi

# Создаем правило sudo
SUDOERS_FILE="/etc/sudoers.d/vpn-wg-access"
cat > "$SUDOERS_FILE" << EOF
# Разрешить пользователю $USER выполнять команду wg без пароля
$USER ALL=(ALL) NOPASSWD: /usr/bin/wg
$USER ALL=(ALL) NOPASSWD: /usr/bin/wg-quick
EOF

chmod 0440 "$SUDOERS_FILE"

# Проверяем синтаксис sudoers
if visudo -c -f "$SUDOERS_FILE" 2>/dev/null; then
    echo "✅ Правило sudo добавлено успешно"
    echo ""
    echo "Теперь пользователь $USER может выполнять:"
    echo "  sudo wg show wg0"
    echo "  sudo wg-quick up wg0"
    echo "без ввода пароля"
else
    echo "❌ Ошибка в синтаксисе sudoers файла"
    rm -f "$SUDOERS_FILE"
    exit 1
fi

