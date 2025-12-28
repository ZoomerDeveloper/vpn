import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Tariff } from './entities/tariff.entity';

@Injectable()
export class TariffsService {
  constructor(
    @InjectRepository(Tariff)
    private tariffsRepository: Repository<Tariff>,
  ) {}

  async findAll(): Promise<Tariff[]> {
    return this.tariffsRepository.find({
      where: { isActive: true },
      order: { price: 'ASC' },
    });
  }

  async findById(id: string): Promise<Tariff> {
    const tariff = await this.tariffsRepository.findOne({ where: { id } });

    if (!tariff) {
      throw new NotFoundException(`Tariff with ID ${id} not found`);
    }

    return tariff;
  }

  async create(createTariffDto: {
    name: string;
    description?: string;
    price: number;
    currency?: string;
    durationDays: number;
    devicesLimit?: number;
  }): Promise<Tariff> {
    const tariff = this.tariffsRepository.create({
      name: createTariffDto.name,
      description: createTariffDto.description,
      price: createTariffDto.price,
      currency: createTariffDto.currency || 'RUB',
      durationDays: createTariffDto.durationDays,
      devicesLimit: createTariffDto.devicesLimit || 1,
    });

    return this.tariffsRepository.save(tariff);
  }

  async update(id: string, updateData: Partial<Tariff>): Promise<Tariff> {
    await this.tariffsRepository.update(id, updateData);
    return this.findById(id);
  }

  async delete(id: string): Promise<void> {
    await this.tariffsRepository.update(id, { isActive: false });
  }
}

