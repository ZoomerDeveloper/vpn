# Настройка SSH для админки

Для того, чтобы админка могла видеть статус подключения peer'ов на удаленных WireGuard серверах, нужно настроить SSH ключи на основном сервере (где запущен backend).

## Шаг 1: Создание SSH ключа на основном сервере

На основном сервере (где запущен backend):

```bash
# Проверить существующие ключи
ls -la ~/.ssh/

# Если ключей нет, создать новый
ssh-keygen -t ed25519 -C "vpn-backend" -f ~/.ssh/id_ed25519 -N ""

# Или использовать RSA (если ed25519 не поддерживается)
ssh-keygen -t rsa -b 4096 -C "vpn-backend" -f ~/.ssh/id_rsa -N ""
```

## Шаг 2: Копирование ключа на WireGuard сервер

Узнать IP адрес WireGuard сервера (server2):

```bash
# На server2 выполните:
hostname -I
# Или:
ip addr show | grep "inet " | grep -v 127.0.0.1
```

На основном сервере скопировать ключ:

```bash
# Замените SERVER2_IP на IP адрес вашего server2
SERVER2_IP="YOUR_SERVER2_IP"

# Используя ssh-copy-id (если установлен)
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@${SERVER2_IP}

# Или вручную:
cat ~/.ssh/id_ed25519.pub | ssh root@${SERVER2_IP} \
  "mkdir -p ~/.ssh && \
   chmod 700 ~/.ssh && \
   cat >> ~/.ssh/authorized_keys && \
   chmod 600 ~/.ssh/authorized_keys"
```

## Шаг 3: Проверка подключения

На основном сервере проверить, что SSH подключение работает без пароля:

```bash
# Замените SERVER2_IP на IP адрес вашего server2
ssh -o BatchMode=yes root@SERVER2_IP "wg show wg0"

# Если команда выполняется без запроса пароля, всё настроено правильно
```

## Шаг 4: Проверка в логах backend

После настройки SSH ключей, проверьте логи backend:

```bash
# На основном сервере
journalctl -u vpn-backend -f

# Или если запущено через pm2/node
# Проверьте логи в соответствующем месте
```

В логах должны быть сообщения:
- `Checking remote server: SERVER2_IP`
- `SSH command succeeded`
- `Server server2: found X peers`

Если есть ошибки:
- `Permission denied` - SSH ключ не скопирован или права неправильные
- `Connection refused` - SSH сервис не запущен на server2
- `Connection timed out` - Firewall блокирует порт 22 или неправильный IP

## Решение проблем

### Проблема: Permission denied (publickey)

**Решение:**

1. Проверить права на ключи на основном сервере:
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

2. Проверить права на server2:
```bash
# На server2
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

3. Проверить содержимое authorized_keys на server2:
```bash
# На server2
cat ~/.ssh/authorized_keys
# Должен быть публичный ключ с основного сервера
```

### Проблема: Connection refused

**Решение:**

Проверить что SSH сервис запущен на server2:

```bash
# На server2
systemctl status ssh
# Или
systemctl status sshd

# Если не запущен:
systemctl start ssh
systemctl enable ssh
```

### Проблема: Connection timed out

**Решение:**

1. Проверить что firewall разрешает SSH (порт 22):
```bash
# На server2
ufw status
# Если firewall активен, разрешить SSH:
ufw allow 22/tcp
```

2. Проверить правильность IP адреса в базе данных:
```bash
# На основном сервере, через API или напрямую в БД
# Проверить поле publicIp сервера server2
```

## Использование SSH config (опционально)

Для удобства можно настроить SSH config на основном сервере:

```bash
# На основном сервере
nano ~/.ssh/config

# Добавить:
Host server2
    HostName SERVER2_IP
    User root
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
```

Тогда можно подключаться просто: `ssh server2`

Но в коде backend мы используем прямое указание IP, так что config не обязателен.

## Проверка работы админки

После настройки SSH ключей:

1. Перезапустить backend:
```bash
systemctl restart vpn-backend
```

2. Открыть админку и проверить статус peer'ов на server2
3. В логах должны быть сообщения о успешной проверке server2

