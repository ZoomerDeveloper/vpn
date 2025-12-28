# Руководство по применению миграции

## Проблема

После добавления новых полей в `VpnServer` entity (`ping`, `lastHealthCheck`, `isHealthy`, `priority`, `region`), база данных не была обновлена, что вызывает ошибку 500 при попытке обновить сервер.

## Решение

Нужно применить миграцию базы данных.

### Шаг 1: Перезапустить backend в режиме development (если synchronize включен)

Если у вас `NODE_ENV=development`, TypeORM автоматически синхронизирует схему:

```bash
cd /opt/vpn-service/backend
NODE_ENV=development npm run start:prod
```

После запуска закройте и запустите в production режиме.

### Шаг 2: Применить миграцию (рекомендуется)

```bash
cd /opt/vpn-service/backend

# Запустить миграцию
npm run migration:run
```

### Шаг 3: Альтернатива - SQL напрямую (рекомендуется)

Если миграция не работает из-за дубликатов, используйте скрипт:

```bash
cd /opt/vpn-service
bash scripts/apply-migration-sql.sh
```

Или вручную:

```bash
cd /opt/vpn-service/backend

# Загрузить переменные из .env
export $(cat .env | grep -v '^#' | xargs)

# Применить SQL
PGPASSWORD="$DB_PASSWORD" psql -h "${DB_HOST:-localhost}" -U "$DB_USERNAME" -d "$DB_DATABASE" << EOF
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS ping INTEGER;
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS "lastHealthCheck" TIMESTAMP;
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS "isHealthy" BOOLEAN DEFAULT true;
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 100;
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS region VARCHAR;
EOF
```

### Шаг 4: Перезапустить backend

```bash
sudo systemctl restart vpn-backend
# или
cd /opt/vpn-service/backend
npm run start:prod
```

### Шаг 5: Проверить

```bash
# Проверить что поля добавлены
psql -U vpn_user -d vpn_service -c "\d vpn_servers"

# Проверить API
curl http://localhost:3000/wireguard/servers | jq '.[0] | {name, priority, region, isHealthy}'
```

## После применения миграции

Теперь можно обновлять серверы:

```bash
# Получить ID сервера
SERVER_ID=$(curl -s http://localhost:3000/wireguard/servers | jq -r '.[0].id')

# Обновить приоритет и регион
curl -X PATCH http://localhost:3000/wireguard/servers/$SERVER_ID \
  -H "Content-Type: application/json" \
  -d '{"priority": 10, "region": "sa"}'
```

