import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { VpnPeer } from './entities/vpn-peer.entity';
import { UsersService } from '../users/users.service';
import { WireguardService } from '../wireguard/wireguard.service';
import { TariffsService } from '../tariffs/tariffs.service';
import { User, UserStatus } from '../users/entities/user.entity';

@Injectable()
export class VpnService {
  private readonly logger = new Logger(VpnService.name);

  constructor(
    @InjectRepository(VpnPeer)
    private peersRepository: Repository<VpnPeer>,
    private usersService: UsersService,
    private wireguardService: WireguardService,
    private tariffsService: TariffsService,
  ) {}

  /**
   * Создает новый VPN peer для пользователя
   */
  async createPeer(userId: string): Promise<{ peer: VpnPeer; config: string }> {
    const user = await this.usersService.findById(userId);

    // Проверяем статус пользователя
    if (user.status === UserStatus.EXPIRED || user.status === UserStatus.BLOCKED) {
      throw new BadRequestException('User account is expired or blocked');
    }

    // Получаем тариф для проверки лимита устройств
    let devicesLimit = 1;
    if (user.tariffId) {
      const tariff = await this.tariffsService.findById(user.tariffId);
      devicesLimit = tariff.devicesLimit;
    }

    // Проверяем количество активных peers
    const activePeers = await this.peersRepository.count({
      where: { userId, isActive: true },
    });

    if (activePeers >= devicesLimit) {
      throw new BadRequestException(
        `Device limit reached (${devicesLimit}). Please remove an existing device first.`,
      );
    }

    // Получаем доступный сервер
    const server = await this.wireguardService.getAvailableServer();

    // Генерируем ключи
    const { privateKey, publicKey } = await this.wireguardService.generateKeyPair();
    const presharedKey = await this.wireguardService.generatePresharedKey();

    // Выделяем IP
    const allocatedIp = this.wireguardService.allocateIp(server);

    // Создаем peer в БД
    const peer = this.peersRepository.create({
      userId,
      serverId: server.id,
      publicKey,
      privateKey,
      presharedKey,
      allocatedIp,
      isActive: true,
    });

    await this.peersRepository.save(peer);

    // Добавляем peer на WireGuard сервер
    try {
      await this.wireguardService.addPeer(server.id, publicKey, allocatedIp, presharedKey);
    } catch (error) {
      // Если не удалось добавить на сервер, удаляем из БД
      await this.peersRepository.remove(peer);
      throw new BadRequestException(`Failed to add peer to server: ${error.message}`);
    }

    // Генерируем конфиг
    const config = await this.wireguardService.generateConfig(
      server,
      privateKey,
      publicKey,
      presharedKey,
      allocatedIp,
    );

    this.logger.log(`VPN peer created for user ${userId}`);

    return { peer, config };
  }

  /**
   * Получает конфиг для существующего peer
   */
  async getPeerConfig(peerId: string): Promise<string> {
    const peer = await this.peersRepository.findOne({
      where: { id: peerId },
      relations: ['server'],
    });

    if (!peer) {
      throw new BadRequestException('Peer not found');
    }

    if (!peer.isActive) {
      throw new BadRequestException('Peer is not active');
    }

    const config = await this.wireguardService.generateConfig(
      peer.server,
      peer.privateKey,
      peer.publicKey,
      peer.presharedKey,
      peer.allocatedIp,
    );

    return config;
  }

  /**
   * Получает все активные peers пользователя
   */
  async getUserPeers(userId: string): Promise<VpnPeer[]> {
    return this.peersRepository.find({
      where: { userId, isActive: true },
      relations: ['server'],
      order: { createdAt: 'DESC' },
    });
  }

  /**
   * Деактивирует peer
   */
  async deactivatePeer(peerId: string, userId?: string): Promise<void> {
    const peer = await this.peersRepository.findOne({
      where: { id: peerId },
      relations: ['server'],
    });

    if (!peer) {
      throw new BadRequestException('Peer not found');
    }

    if (userId && peer.userId !== userId) {
      throw new BadRequestException('Unauthorized');
    }

    // Удаляем peer с сервера
    try {
      await this.wireguardService.removePeer(peer.serverId, peer.publicKey);
    } catch (error) {
      this.logger.warn(`Failed to remove peer from server: ${error.message}`);
    }

    // Деактивируем в БД
    peer.isActive = false;
    await this.peersRepository.save(peer);

    this.logger.log(`VPN peer ${peerId} deactivated`);
  }

  /**
   * Реактивирует peer
   */
  async activatePeer(peerId: string, userId?: string): Promise<void> {
    const peer = await this.peersRepository.findOne({
      where: { id: peerId },
      relations: ['server'],
    });

    if (!peer) {
      throw new BadRequestException('Peer not found');
    }

    if (userId && peer.userId !== userId) {
      throw new BadRequestException('Unauthorized');
    }

    // Добавляем peer обратно на сервер
    try {
      await this.wireguardService.addPeer(
        peer.serverId,
        peer.publicKey,
        peer.allocatedIp,
        peer.presharedKey,
      );
    } catch (error) {
      throw new BadRequestException(`Failed to activate peer: ${error.message}`);
    }

    peer.isActive = true;
    await this.peersRepository.save(peer);

    this.logger.log(`VPN peer ${peerId} activated`);
  }
}

