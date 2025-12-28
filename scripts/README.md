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

Настройка WireGuard на VPN сервере (запускается НА сервере, не через SSH).

## Пример полного деплоя

```bash
# 1. Настройка сервера
SSHPASS='your_ssh_password' ./scripts/setup-server.sh 199.247.7.185 root

# 2. Настройка PostgreSQL
SSHPASS='your_ssh_password' ./scripts/setup-postgres.sh 199.247.7.185 root
# Введите пароль для PostgreSQL пользователя

# 3. Деплой приложения
SSHPASS='your_ssh_password' ./scripts/deploy.sh 199.247.7.185 root https://github.com/your/repo.git

# 4. Подключитесь к серверу для настройки .env
ssh root@199.247.7.185

# 5. На сервере настройте .env файлы
cd /opt/vpn-service/backend
cp .env.example .env
nano .env  # Настройте файл

cd ../bot
cp .env.example .env
nano .env  # Настройте файл

# 6. Запустите миграции и seed
cd /opt/vpn-service/backend
npm run migration:run  # Если есть миграции
ts-node src/database/seeds/seed.ts  # Заполнение тарифов

# 7. Настройте systemd services (см. docs/DEPLOY.md)
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

