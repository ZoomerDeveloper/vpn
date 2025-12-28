import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User, UserStatus } from './entities/user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  async findByTelegramId(telegramId: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { telegramId },
      relations: ['peers', 'payments'],
    });
  }

  async findById(id: string): Promise<User> {
    const user = await this.usersRepository.findOne({
      where: { id },
      relations: ['peers', 'payments'],
    });

    if (!user) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }

    return user;
  }

  async create(telegramId: string, userData?: {
    username?: string;
    firstName?: string;
    lastName?: string;
  }): Promise<User> {
    const user = this.usersRepository.create({
      telegramId,
      username: userData?.username,
      firstName: userData?.firstName,
      lastName: userData?.lastName,
      status: UserStatus.TRIAL,
    });

    return this.usersRepository.save(user);
  }

  async update(id: string, updateData: Partial<User>): Promise<User> {
    await this.usersRepository.update(id, updateData);
    return this.findById(id);
  }

  async startTrial(userId: string, hours: number = 24): Promise<User> {
    const user = await this.findById(userId);
    
    // Убрана проверка trialUsed для тестирования - можно использовать trial неограниченное количество раз
    // if (user.trialUsed) {
    //   throw new Error('Trial already used');
    // }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + hours * 60 * 60 * 1000);

    user.status = UserStatus.TRIAL;
    // Убрана установка trialUsed = true для тестирования
    // user.trialUsed = true;
    user.trialStartedAt = now;
    user.trialExpiresAt = expiresAt;
    user.expireAt = expiresAt;

    return this.usersRepository.save(user);
  }

  async activateSubscription(userId: string, tariffId: string, expireAt: Date): Promise<User> {
    const user = await this.findById(userId);
    
    user.status = UserStatus.ACTIVE;
    user.tariffId = tariffId;
    user.expireAt = expireAt;

    return this.usersRepository.save(user);
  }

  async resetTrial(userId: string): Promise<User> {
    const user = await this.findById(userId);
    
    user.trialUsed = false;
    user.trialStartedAt = null;
    user.trialExpiresAt = null;
    user.status = UserStatus.TRIAL;
    
    return this.usersRepository.save(user);
  }

  async checkExpiration(): Promise<void> {
    const now = new Date();
    const expiredUsers = await this.usersRepository
      .createQueryBuilder('user')
      .where('user.expireAt < :now', { now })
      .andWhere('user.status IN (:...statuses)', {
        statuses: [UserStatus.ACTIVE, UserStatus.TRIAL],
      })
      .getMany();

    for (const user of expiredUsers) {
      user.status = UserStatus.EXPIRED;
      await this.usersRepository.save(user);
    }
  }

  async getAll(): Promise<User[]> {
    return this.usersRepository.find({
      relations: ['peers', 'peers.server', 'payments'],
      order: { createdAt: 'DESC' },
    });
  }
}

