# Мобильное приложение для VPN

## Обзор

Для создания мобильного приложения VPN-сервиса необходимо интегрировать WireGuard SDK в нативное или кроссплатформенное приложение.

## Варианты разработки

### 1. Нативная разработка (Рекомендуется)

#### iOS (Swift)
- **WireGuard библиотека:** Используйте официальный WireGuard для iOS через CocoaPods или Swift Package Manager
- **API:** Создайте REST клиент для взаимодействия с Backend API
- **Архитектура:** MVVM или Clean Architecture
- **Основные функции:**
  - Авторизация через Telegram Bot API (OAuth)
  - Получение конфигурации WireGuard через API
  - Автоматическое подключение/отключение VPN
  - Управление подпиской и тарифами
  - Статистика использования

**Необходимые зависимости:**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/WireGuard/wireguard-apple", from: "1.0.0"),
    .package(url: "https://github.com/Alamofire/Alamofire", from: "5.0.0") // HTTP клиент
]
```

#### Android (Kotlin/Java)
- **WireGuard библиотека:** Используйте официальный WireGuard для Android
- **API:** Retrofit или Ktor для HTTP запросов
- **Архитектура:** MVVM с Jetpack Compose или XML layouts
- **Основные функции:** Аналогично iOS

**Необходимые зависимости:**
```gradle
// build.gradle
dependencies {
    implementation 'com.wireguard.android:tunnel:1.0.20211112'
    implementation 'com.squareup.retrofit2:retrofit:2.9.0'
    implementation 'com.squareup.retrofit2:converter-gson:2.9.0'
}
```

### 2. Кроссплатформенная разработка

#### Flutter (Dart)
- **WireGuard плагин:** Используйте нативные плагины для WireGuard
- **HTTP клиент:** `http` или `dio` пакеты
- **Плюсы:** Единая кодовая база для iOS и Android
- **Минусы:** Может быть сложнее интегрировать WireGuard нативно

**Необходимые зависимости:**
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
  # WireGuard плагин нужно будет создать или использовать существующий
```

#### React Native
- **WireGuard библиотека:** Используйте нативные модули для WireGuard
- **HTTP клиент:** `axios` или `fetch`
- **Плюсы:** Можно переиспользовать код из веб-приложения
- **Минусы:** Требует нативной интеграции WireGuard

### 3. Гибридный подход

Использовать готовое приложение WireGuard и интегрировать его с вашим Backend API через Deep Links или URL Schemes.

## Архитектура приложения

### Основные компоненты

1. **Authentication Module**
   - Авторизация через Telegram Bot API
   - Сохранение токенов (Keychain/Keystore)
   - Refresh токенов

2. **VPN Module**
   - Интеграция WireGuard SDK
   - Управление VPN соединением
   - Мониторинг состояния подключения

3. **API Client**
   - REST API клиент для Backend
   - Endpoints:
     - `/users/telegram/:telegramId` - получение пользователя
     - `/vpn/users/:userId/peers` - список устройств
     - `/vpn/users/:userId/peers` (POST) - создание нового peer
     - `/vpn/peers/:peerId/config` - получение конфигурации
     - `/tariffs` - список тарифов
     - `/payments` - управление платежами

4. **Subscription Module**
   - Отображение тарифов
   - Управление подпиской
   - Отслеживание срока действия

5. **UI Layer**
   - Экран подключения/отключения VPN
   - Список серверов (если несколько)
   - Настройки
   - Профиль пользователя
   - Платежи и тарифы

## API Integration

### Получение конфигурации WireGuard

```typescript
// Пример TypeScript (можно адаптировать для любого языка)

interface WireGuardConfig {
  privateKey: string;
  publicKey: string;
  endpoint: string;
  allowedIPs: string;
  dns: string;
}

async function getVPNConfig(userId: string): Promise<WireGuardConfig> {
  // 1. Создать или получить peer
  const peerResponse = await api.post(`/vpn/users/${userId}/peers`);
  const peer = peerResponse.data.peer;
  
  // 2. Получить конфигурацию
  const configResponse = await api.get(`/vpn/peers/${peer.id}/config`);
  return parseWireGuardConfig(configResponse.data.config);
}
```

### Формат конфигурации WireGuard

```
[Interface]
PrivateKey = <private_key>
Address = 10.0.0.2/32
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = <server_public_key>
Endpoint = 199.247.7.185:51820
AllowedIPs = 0.0.0.0/0, ::/0
PresharedKey = <preshared_key>
PersistentKeepalive = 25
```

## Рекомендуемый стек для MVP

### iOS
- **Язык:** Swift
- **UI Framework:** SwiftUI
- **Networking:** URLSession или Alamofire
- **WireGuard:** WireGuard-iOS (official)
- **Architecture:** MVVM + Combine

### Android
- **Язык:** Kotlin
- **UI Framework:** Jetpack Compose
- **Networking:** Retrofit + OkHttp
- **WireGuard:** wireguard-android (official)
- **Architecture:** MVVM + Coroutines + Flow

## Основные экраны приложения

1. **Splash Screen**
   - Проверка авторизации
   - Загрузка данных пользователя

2. **VPN Control Screen**
   - Кнопка подключения/отключения
   - Статус подключения
   - Выбор сервера (если несколько)
   - Статистика (опционально)

3. **Subscription Screen**
   - Текущая подписка
   - Остаток дней
   - Список тарифов
   - Продление подписки

4. **Profile Screen**
   - Информация о пользователе
   - Список устройств
   - Настройки
   - Выход

5. **Settings Screen**
   - Настройки VPN
   - Уведомления
   - О приложении

## Безопасность

1. **Хранение ключей:**
   - iOS: Keychain Services
   - Android: Keystore System

2. **API Communication:**
   - HTTPS только
   - Certificate Pinning (опционально)
   - JWT токены с refresh

3. **WireGuard Configuration:**
   - Хранение конфигурации в зашифрованном виде
   - Никогда не логировать приватные ключи

## Развертывание

### iOS
- App Store через Apple Developer Account ($99/год)
- TestFlight для бета-тестирования

### Android
- Google Play Store ($25 единоразово)
- Internal Testing / Closed Beta для тестирования

## Альтернативный подход (Проще для MVP)

Вместо создания отдельного приложения, можно:

1. Использовать официальное приложение WireGuard
2. Создать веб-интерфейс для управления:
   - Генерация QR-кодов для быстрой настройки
   - Управление подпиской
   - История платежей
   - Управление устройствами

3. Интегрировать веб-интерфейс в Telegram бота через Web Apps (Telegram Mini Apps)

## Полезные ресурсы

- [WireGuard iOS Documentation](https://github.com/WireGuard/wireguard-apple)
- [WireGuard Android Documentation](https://github.com/WireGuard/wireguard-android)
- [WireGuard Protocol Specification](https://www.wireguard.com/protocol/)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Telegram Web Apps](https://core.telegram.org/bots/webapps)

