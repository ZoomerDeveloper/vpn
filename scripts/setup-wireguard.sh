#!/bin/bash

# Скрипт для настройки WireGuard на Ubuntu сервере

set -e

echo "🔧 Setting up WireGuard..."

# Обновляем систему
apt-get update
apt-get upgrade -y

# Устанавливаем WireGuard
apt-get install -y wireguard wireguard-tools iptables qrencode

# Включаем IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p

# Создаем директорию для конфигов
mkdir -p /etc/wireguard
cd /etc/wireguard

# Генерируем ключи сервера (сохраняем для последующей регистрации)
if [ ! -f server_private.key ]; then
    wg genkey | tee server_private.key | wg pubkey > server_public.key
    chmod 600 server_private.key
    chmod 644 server_public.key
    echo "✓ Generated server keys"
    echo "✓ Ключи сохранены в /etc/wireguard/ для последующей регистрации"
fi

# Читаем ключи
SERVER_PRIVATE_KEY=$(cat server_private.key)
SERVER_PUBLIC_KEY=$(cat server_public.key)

# Получаем публичный IP (можно изменить на статический)
PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
PRIVATE_IP="10.0.0.1"
NETWORK="10.0.0.0/24"
INTERFACE="wg0"
PORT=51820

# Определяем основной сетевой интерфейс
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$MAIN_INTERFACE" ]; then
    MAIN_INTERFACE="eth0"
    echo "⚠️  Не удалось определить основной интерфейс, используем eth0"
else
    echo "✓ Основной интерфейс: $MAIN_INTERFACE"
fi

# Создаем конфиг WireGuard
cat > /etc/wireguard/${INTERFACE}.conf <<EOF
[Interface]
Address = ${PRIVATE_IP}/24
ListenPort = ${PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${MAIN_INTERFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${MAIN_INTERFACE} -j MASQUERADE

# Peers will be added here by the backend
EOF

chmod 600 /etc/wireguard/${INTERFACE}.conf

# Включаем и запускаем WireGuard
systemctl enable wg-quick@${INTERFACE}
systemctl start wg-quick@${INTERFACE}

echo "✓ WireGuard configured"
echo ""
echo "Server Public Key: ${SERVER_PUBLIC_KEY}"
echo "Server Public IP: ${PUBLIC_IP}"
echo "Server Private IP: ${PRIVATE_IP}"
echo "Network: ${NETWORK}"
echo "Port: ${PORT}"
echo ""
echo "Add this server to the backend with:"
echo "  POST /wireguard/servers"
echo "  {"
echo "    \"name\": \"server1\","
echo "    \"host\": \"${PUBLIC_IP}\","
echo "    \"port\": ${PORT},"
echo "    \"publicIp\": \"${PUBLIC_IP}\","
echo "    \"privateIp\": \"${PRIVATE_IP}\","
echo "    \"endpoint\": \"${PUBLIC_IP}\","
echo "    \"network\": \"${NETWORK}\","
echo "    \"dns\": \"1.1.1.1,8.8.8.8\","
echo "    \"publicKey\": \"${SERVER_PUBLIC_KEY}\","
echo "    \"privateKey\": \"${SERVER_PRIVATE_KEY}\""
echo "  }"

