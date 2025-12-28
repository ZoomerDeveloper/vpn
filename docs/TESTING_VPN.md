# Тестирование VPN без реального пользователя в РФ

## Локальное тестирование

### 1. Проверка конфигурации

```bash
cd /opt/vpn-service/scripts
bash test-vpn-locally.sh http://localhost:3000 USER_ID
```

Этот скрипт:
- Получает конфигурацию пользователя
- Проверяет структуру конфигурации
- Проверяет доступность endpoint
- Проверяет DNS серверы
- Валидирует синтаксис конфигурации
- Сохраняет конфигурацию в `/tmp/test-vpn-*.conf` для дальнейшего использования

### 2. Проверка подключения peer'а

```bash
# Показать все активные peer'ы
bash test-vpn-connectivity.sh

# Проверить конкретный peer
bash test-vpn-connectivity.sh PEER_PUBLIC_KEY
```

### 3. Проверка статуса на сервере

```bash
# Показать все peer'ы
sudo wg show wg0

# Проверить конкретный peer
sudo wg show wg0 | grep -A 5 "peer: PUBLIC_KEY"
```

## Тестирование конфигурации локально

### Вариант 1: На сервере (если WireGuard установлен)

```bash
# Конфигурация сохранена в /tmp/test-vpn-*.conf
CONFIG_FILE="/tmp/test-vpn-XXXXX.conf"

# Поднять интерфейс (создаст новый интерфейс wg1, wg2 и т.д.)
sudo wg-quick up $CONFIG_FILE

# Проверить подключение
curl ifconfig.me  # Должен показать IP сервера
dig @1.1.1.1 google.com

# Закрыть интерфейс
sudo wg-quick down $CONFIG_FILE
```

### Вариант 2: На другом устройстве

1. Получить конфигурацию:
   ```bash
   cat /tmp/test-vpn-*.conf
   ```

2. Скопировать конфигурацию на устройство

3. Импортировать в WireGuard приложение

4. Подключиться и проверить

## Проверка доступности порта извне

### Онлайн-сервисы

1. **YouGetSignal:**
   - https://www.yougetsignal.com/tools/open-ports/
   - Введите IP сервера и порт (например, 51820)
   - Выберите UDP
   - Проверьте доступность

2. **PortChecker:**
   - https://portchecker.co/
   - Введите IP и порт
   - Проверьте UDP

3. **Canyouseeme:**
   - https://canyouseeme.org/
   - Работает только для TCP, но можно проверить общую доступность IP

### Через командную строку

```bash
# С другого сервера (если есть)
nc -uz SERVER_IP PORT

# Или через telnet (только TCP)
telnet SERVER_IP PORT
```

## Эмуляция проблем в РФ

### 1. Блокировка порта

Если порт 51820/UDP заблокирован, попробуйте другой порт:

```bash
sudo bash change-wg-port.sh 443
```

### 2. Блокировка DNS

Проверьте работу разных DNS серверов:

```bash
# Cloudflare
dig @1.1.1.1 google.com

# Google
dig @8.8.8.8 google.com

# Yandex (российский)
dig @77.88.8.8 google.com
```

### 3. Тестирование с VPN из РФ

Если у вас есть доступ к VPN/прокси в РФ:

1. Подключитесь к VPN в РФ
2. Попробуйте подключиться к вашему WireGuard серверу
3. Проверьте работает ли соединение

## Проверка через Docker контейнер

Можно создать тестовый контейнер с WireGuard:

```bash
# Создать Dockerfile
cat > Dockerfile.test <<EOF
FROM alpine:latest
RUN apk add --no-cache wireguard-tools curl bind-tools
COPY test-config.conf /etc/wireguard/wg0.conf
CMD ["wg-quick", "up", "wg0"] && sleep 3600
EOF

# Собрать и запустить
docker build -f Dockerfile.test -t vpn-test .
docker run --rm --cap-add=NET_ADMIN --cap-add=SYS_MODULE vpn-test
```

## Автоматизированное тестирование

```bash
#!/bin/bash
# test-vpn-full.sh

USER_ID="USER_ID_HERE"

# 1. Диагностика
bash diagnose-vpn-ru-detailed.sh http://localhost:3000 $USER_ID

# 2. Локальное тестирование
bash test-vpn-locally.sh http://localhost:3000 $USER_ID

# 3. Проверка подключения
PEER_KEY=$(curl -s http://localhost:3000/vpn/users/$USER_ID/peers | jq -r '.[0].publicKey')
bash test-vpn-connectivity.sh $PEER_KEY

echo "Тестирование завершено!"
```

## Чеклист для проверки

- [ ] Конфигурация правильно сформирована
- [ ] DNS указан и содержит надежные серверы (1.1.1.1, 8.8.8.8)
- [ ] AllowedIPs = 0.0.0.0/0,::/0 (весь трафик через VPN)
- [ ] Endpoint доступен (порт открыт)
- [ ] Peer добавлен на WireGuard сервер
- [ ] Маршрутизация настроена (IP forwarding, NAT)
- [ ] Порт не заблокирован (проверено извне)
- [ ] Конфигурация валидна (wg-quick может ее распарсить)

## Полезные команды

```bash
# Проверить что порт слушается
sudo ss -ulnp | grep 51820

# Проверить firewall правила
sudo iptables -L -n -v
sudo ufw status

# Проверить логи WireGuard
sudo journalctl -u wg-quick@wg0 -n 50

# Мониторинг подключений в реальном времени
watch -n 1 'sudo wg show'
```

