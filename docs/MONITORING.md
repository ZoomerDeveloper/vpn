# Мониторинг и алерты

## Обзор

Рекомендуемая система мониторинга для VPN-сервиса включает мониторинг серверов, приложений, базы данных и сетевого трафика.

## 1. Мониторинг сервера

### Prometheus + Grafana (Рекомендуется)

**Установка Prometheus Node Exporter:**
```bash
# Скачать и установить node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/

# Создать systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

**Метрики для мониторинга:**
- CPU usage
- Memory usage
- Disk usage
- Network traffic
- Uptime

### Простой скрипт мониторинга (Минимальный вариант)

Создайте скрипт для проверки состояния:

```bash
#!/bin/bash
# scripts/health-check.sh

# Проверка Backend
if ! curl -s http://localhost:3000/health > /dev/null; then
    echo "❌ Backend API недоступен"
    exit 1
fi

# Проверка Bot
if ! systemctl is-active --quiet vpn-bot; then
    echo "❌ VPN Bot не запущен"
    exit 1
fi

# Проверка PostgreSQL
if ! systemctl is-active --quiet postgresql; then
    echo "❌ PostgreSQL не запущен"
    exit 1
fi

# Проверка WireGuard
if ! systemctl is-active --quiet wg-quick@wg0; then
    echo "❌ WireGuard не запущен"
    exit 1
fi

echo "✅ Все сервисы работают"
```

## 2. Мониторинг приложений

### Health Check Endpoints

Добавьте расширенные health checks в Backend:

```typescript
// backend/src/app.controller.ts
@Get('health')
async health() {
  return {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    services: {
      database: await this.checkDatabase(),
      wireguard: await this.checkWireGuard(),
    }
  };
}
```

### Логирование

Используйте Winston или Pino для структурированного логирования:

```typescript
import { Logger } from '@nestjs/common';

// Автоматическое логирование ошибок
// Настроить ротацию логов через logrotate
```

## 3. Алерты

### Telegram Bot для алертов

Создайте простой бот для отправки уведомлений:

```typescript
// backend/src/alerts/telegram-alert.service.ts
@Injectable()
export class TelegramAlertService {
  private readonly bot: Telegraf;

  async sendAlert(message: string) {
    await this.bot.telegram.sendMessage(
      process.env.ALERT_CHAT_ID,
      `🚨 Alert: ${message}`
    );
  }
}
```

### Cron задача для проверки

```typescript
// backend/src/tasks/health-check.task.ts
@Injectable()
export class HealthCheckTask {
  @Cron('*/5 * * * *') // Каждые 5 минут
  async checkHealth() {
    // Проверка сервисов
    // Отправка алертов при проблемах
  }
}
```

### Простой скрипт с отправкой в Telegram

```bash
#!/bin/bash
# scripts/monitor.sh

# Получить токен бота и chat_id из .env
BOT_TOKEN="your_bot_token"
CHAT_ID="your_chat_id"

# Проверка
if ! curl -s http://localhost:3000/health > /dev/null; then
    curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=🚨 Backend API недоступен на сервере $(hostname)"
fi
```

## 4. Мониторинг WireGuard

### Статистика подключений

```bash
# Скрипт для мониторинга активных подключений
#!/bin/bash
# scripts/wg-stats.sh

ACTIVE_PEERS=$(wg show wg0 | grep -c "peer:")
echo "Active peers: $ACTIVE_PEERS"

# Отправка метрик в Prometheus или лог
```

### Мониторинг трафика

WireGuard предоставляет статистику трафика для каждого peer:

```bash
wg show wg0 dump | awk '{print "peer:", $1, "received:", $6, "sent:", $7}'
```

## 5. Мониторинг базы данных

### PostgreSQL мониторинг

```sql
-- Проверка размера БД
SELECT pg_size_pretty(pg_database_size('vpn_service'));

-- Количество подключений
SELECT count(*) FROM pg_stat_activity;

-- Медленные запросы
SELECT query, mean_exec_time 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;
```

### Настроить pg_stat_statements

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

## 6. Рекомендуемая структура мониторинга

### Минимальный набор (MVP)

1. **Cron задача** проверки здоровья каждые 5 минут
2. **Telegram бот** для алертов
3. **Health check endpoint** в Backend
4. **Логирование** в файлы с ротацией

### Расширенный набор

1. **Prometheus** для сбора метрик
2. **Grafana** для визуализации
3. **Alertmanager** для управления алертами
4. **ELK Stack** или Loki для логов

## 7. Быстрая настройка простого мониторинга

```bash
# 1. Создать скрипт мониторинга
cat > /opt/vpn-service/scripts/monitor.sh <<'EOF'
#!/bin/bash
# Проверки здоровья сервисов
# Отправка алертов в Telegram
EOF

chmod +x /opt/vpn-service/scripts/monitor.sh

# 2. Добавить в crontab
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/vpn-service/scripts/monitor.sh") | crontab -
```

## Полезные команды

```bash
# Проверка логов
sudo journalctl -u vpn-backend -f
sudo journalctl -u vpn-bot -f

# Проверка ресурсов
htop
df -h
free -h

# Проверка сети
ss -tulpn
netstat -tulpn

# Проверка WireGuard
wg show
wg show wg0 dump
```

