# Скрипты для настройки сервера

## Требования

Установите `sshpass` для работы скриптов:

```bash
# macOS
brew install hudochenkov/sshpass/sshpass

# Ubuntu/Debian
sudo apt install sshpass
```

## Скрипты

### 1. setup-server.sh

Базовая настройка сервера: установка пакетов, настройка firewall, создание пользователей.

**Использование:**

```bash
# С паролем через переменную окружения
SSHPASS='your_password' ./scripts/setup-server.sh 199.247.7.185 root

# Или будет запрошен пароль
./scripts/setup-server.sh 199.247.7.185 root
```

**Что делает:**
- Обновляет систему
- Устанавливает базовые пакеты
- Устанавливает PostgreSQL, Node.js 18, WireGuard
- Настраивает IP forwarding
- Настраивает firewall (UFW)
- Создает пользователя vpn

### 2. setup-postgres.sh

Настройка PostgreSQL: создание БД и пользователя.

**Использование:**

```bash
SSHPASS='your_password' ./scripts/setup-postgres.sh 199.247.7.185 root
# Будет запрошен пароль для PostgreSQL пользователя
```

**Что делает:**
- Создает базу данных `vpn_service`
- Создает пользователя `vpn_user`
- Выдает права

### 3. deploy.sh

Полный деплой приложения на сервер.

**Использование:**

```bash
# С URL репозитория
SSHPASS='your_password' ./scripts/deploy.sh 199.247.7.185 root https://github.com/your/repo.git

# Будет запрошен URL репозитория
SSHPASS='your_password' ./scripts/deploy.sh 199.247.7.185 root
```

**Что делает:**
- Выполняет базовую настройку (если не пропущена)
- Клонирует репозиторий
- Устанавливает зависимости
- Собирает проект

### 4. setup-wireguard.sh

Настройка WireGuard на VPN сервере (запускается **НА сервере**, не через SSH).

**Использование:**

```bash
# На сервере
ssh root@your-server
bash /opt/vpn-service/scripts/setup-wireguard.sh
```

**Что делает:**
- Устанавливает WireGuard
- Генерирует ключи сервера
- Настраивает интерфейс wg0
- Включает IP forwarding
- Запускает WireGuard

### 5. register-wireguard-server.sh ⭐

Автоматическая регистрация WireGuard сервера в Backend API (запускается **НА сервере**).

**Использование:**

```bash
# На сервере где настроен WireGuard
ssh root@your-server
cd /opt/vpn-service
bash scripts/register-wireguard-server.sh

# Или с указанием API URL
bash scripts/register-wireguard-server.sh http://localhost:3000 server1
```

**Что делает:**
- Проверяет что WireGuard настроен
- Получает public key и IP адреса
- Регистрирует сервер через Backend API
- Возвращает Server ID

**Важно:** Этот скрипт должен запускаться **после** того как:
1. WireGuard настроен (через setup-wireguard.sh)
2. Backend API запущен
3. БД инициализирована

## Пример полного деплоя

```bash
# 1. Настройка сервера (локально)
SSHPASS='your_ssh_password' ./scripts/setup-server.sh 199.247.7.185 root

# 2. Настройка PostgreSQL (локально)
SSHPASS='your_ssh_password' ./scripts/setup-postgres.sh 199.247.7.185 root

# 3. Деплой приложения (локально)
SSHPASS='your_ssh_password' ./scripts/deploy.sh 199.247.7.185 root https://github.com/your/repo.git

# 4. Подключитесь к серверу
ssh root@199.247.7.185

# 5. На сервере: Настройте .env файлы
cd /opt/vpn-service/backend
nano .env  # Настройте файл

cd ../bot
nano .env  # Настройте файл

# 6. На сервере: Запустите seed
cd /opt/vpn-service/backend
npx ts-node src/database/seeds/seed.ts

# 7. На сервере: Настройте WireGuard (если это VPN сервер)
cd /opt/vpn-service
bash scripts/setup-wireguard.sh

# 8. На сервере: Запустите Backend (в отдельном терминале или через systemd)
cd /opt/vpn-service/backend
npm run start:prod

# 9. На сервере: Зарегистрируйте WireGuard сервер (в другом терминале)
cd /opt/vpn-service
bash scripts/register-wireguard-server.sh http://localhost:3000 server1

# 10. На сервере: Запустите Bot
cd /opt/vpn-service/bot
npm run start
```

## Безопасность

⚠️ **Важно:**
- Не сохраняйте пароли в скриптах
- Используйте переменные окружения для паролей
- После настройки настройте SSH ключи вместо паролей
- Отключите root логин через SSH

## Устранение проблем

**Ошибка "sshpass: command not found":**
```bash
# Установите sshpass (см. Требования выше)
```

**Ошибка подключения:**
- Проверьте правильность IP и пользователя
- Проверьте доступность сервера: `ping 199.247.7.185`
- Проверьте что SSH порт открыт

**Ошибка прав доступа:**
- Убедитесь что запускаете скрипты с правами выполнения: `chmod +x scripts/*.sh`

**Ошибка 500 при /trial:**
- Проверьте что WireGuard сервер зарегистрирован: `curl http://localhost:3000/wireguard/servers`
- Если серверов нет, запустите: `bash scripts/register-wireguard-server.sh`
