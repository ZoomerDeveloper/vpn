import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Patch,
  UseGuards,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { User } from './entities/user.entity';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  async getAll() {
    return this.usersService.getAll();
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.usersService.findById(id);
  }

  @Get('telegram/:telegramId')
  async findByTelegramId(@Param('telegramId') telegramId: string) {
    return this.usersService.findByTelegramId(telegramId);
  }

  @Post()
  async create(@Body() createUserDto: {
    telegramId: string;
    username?: string;
    firstName?: string;
    lastName?: string;
  }) {
    return this.usersService.create(
      createUserDto.telegramId,
      {
        username: createUserDto.username,
        firstName: createUserDto.firstName,
        lastName: createUserDto.lastName,
      },
    );
  }

  @Post(':id/trial')
  async startTrial(
    @Param('id') id: string,
    @Body() body: { hours?: number },
  ) {
    return this.usersService.startTrial(id, body.hours || 24);
  }
}

