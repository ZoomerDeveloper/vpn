import { DataSource } from 'typeorm';
import { Tariff } from '../../tariffs/entities/tariff.entity';

export async function seedTariffs(dataSource: DataSource) {
  const tariffRepository = dataSource.getRepository(Tariff);

  const tariffs = [
    {
      name: '1 месяц',
      description: 'Базовый тариф на 1 месяц',
      price: 299,
      currency: 'RUB',
      durationDays: 30,
      devicesLimit: 1,
      isActive: true,
    },
    {
      name: '1 год',
      description: 'Годовая подписка со скидкой',
      price: 1999,
      currency: 'RUB',
      durationDays: 365,
      devicesLimit: 1,
      isActive: true,
    },
    {
      name: 'Семейный (3 устройства)',
      description: 'Подписка для всей семьи - 3 устройства',
      price: 499,
      currency: 'RUB',
      durationDays: 30,
      devicesLimit: 3,
      isActive: true,
    },
    {
      name: 'Семейный (5 устройств)',
      description: 'Подписка для большой семьи - 5 устройств',
      price: 699,
      currency: 'RUB',
      durationDays: 30,
      devicesLimit: 5,
      isActive: true,
    },
  ];

  for (const tariffData of tariffs) {
    const existing = await tariffRepository.findOne({
      where: { name: tariffData.name },
    });

    if (!existing) {
      const tariff = tariffRepository.create(tariffData);
      await tariffRepository.save(tariff);
      console.log(`✓ Created tariff: ${tariff.name}`);
    } else {
      console.log(`- Tariff already exists: ${tariffData.name}`);
    }
  }
}

