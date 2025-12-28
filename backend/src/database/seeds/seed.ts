import { DataSource } from 'typeorm';
import dataSource from '../data-source';
import { seedTariffs } from './tariffs.seed';

async function runSeeds() {
  try {
    await dataSource.initialize();
    console.log('Database connected');

    await seedTariffs(dataSource);

    console.log('✓ Seeds completed');
    await dataSource.destroy();
  } catch (error) {
    console.error('Error running seeds:', error);
    process.exit(1);
  }
}

runSeeds();

