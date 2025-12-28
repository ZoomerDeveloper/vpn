import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Patch,
  Delete,
} from '@nestjs/common';
import { TariffsService } from './tariffs.service';
import { Tariff } from './entities/tariff.entity';

@Controller('tariffs')
export class TariffsController {
  constructor(private readonly tariffsService: TariffsService) {}

  @Get()
  async findAll() {
    return this.tariffsService.findAll();
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.tariffsService.findById(id);
  }

  @Post()
  async create(@Body() createTariffDto: {
    name: string;
    description?: string;
    price: number;
    currency?: string;
    durationDays: number;
    devicesLimit?: number;
  }) {
    return this.tariffsService.create(createTariffDto);
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body() updateTariffDto: Partial<Tariff>,
  ) {
    return this.tariffsService.update(id, updateTariffDto);
  }

  @Delete(':id')
  async remove(@Param('id') id: string) {
    await this.tariffsService.delete(id);
    return { message: 'Tariff deleted' };
  }
}

