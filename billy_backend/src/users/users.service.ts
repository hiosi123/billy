import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { sha256Hex } from '../common/crypto.util';

@Injectable()
export class UsersService {
  constructor(@InjectRepository(User) private usersRepo: Repository<User>) {}

  findAll() {
    return this.usersRepo.find();
  }

  async findOne(id: number) {
    const user = await this.usersRepo.findOne({ where: { userId: id } });
    if (!user) throw new NotFoundException('유저를 찾을 수 없습니다');
    return user;
  }

  async findByUsername(username: string) {
    const user = await this.usersRepo.findOne({ where: { username } });
    if (!user) throw new NotFoundException('유저를 찾을 수 없습니다');
    return user;
  }

  async create(dto: CreateUserDto) {
    const user = await this.usersRepo.save(
      this.usersRepo.create({ ...dto, password: sha256Hex(dto.password) }),
    );
    return this.findOne(user.userId);
  }

  async update(id: number, dto: UpdateUserDto) {
    const patch: Partial<User> = { ...dto };
    if (dto.password) patch.password = sha256Hex(dto.password);
    await this.usersRepo.update({ userId: id }, patch);
    return this.findOne(id);
  }

  async remove(id: number) {
    await this.usersRepo.delete({ userId: id });
    return { message: '유저가 삭제되었습니다' };
  }
}
