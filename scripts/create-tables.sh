#!/bin/bash

# Скрипт для создания таблиц в БД через запуск приложения
# Использование: запустить на сервере

cd /opt/vpn-service/backend

# Временно включаем синхронизацию для создания таблиц
NODE_ENV=development npm run start:prod &
APP_PID=$!

# Ждем создания таблиц
sleep 5

# Останавливаем приложение
kill $APP_PID 2>/dev/null || true

echo "Таблицы созданы!"

