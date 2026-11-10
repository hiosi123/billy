import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { sha256Hex } from '../common/crypto.util';
import { setPassword } from './password';
import { MigrationService } from '../database/migration.service';

/** 관리자 화면의 계정 한 줄 — 볼 수 있는 건물(소유 + 멤버)까지. */
export interface UserRow {
  userId: number;
  username: string;
  role: string;
  createdAt: Date;
  buildingIds: number[];
  ownedBuildingIds: number[];
}

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private usersRepo: Repository<User>,
    private readonly migrations: MigrationService,
  ) {}

  async findAll(): Promise<UserRow[]> {
    const users = await this.usersRepo.find({ order: { userId: 'ASC' } });
    const owned: { user_id: number; building_id: number }[] = await this.usersRepo.query(
      'SELECT user_id, building_id FROM buildings WHERE user_id IS NOT NULL',
    );
    const members: { user_id: number; building_id: number }[] = this.migrations.isReady()
      ? await this.usersRepo.query('SELECT user_id, building_id FROM building_members')
      : [];
    const ids = (rows: { user_id: number; building_id: number }[], userId: number) =>
      rows.filter((r) => Number(r.user_id) === userId).map((r) => Number(r.building_id));
    return users.map((u) => {
      const own = ids(owned, u.userId);
      return {
        userId: u.userId,
        username: u.username,
        role: u.role,
        createdAt: u.createdAt,
        ownedBuildingIds: own,
        buildingIds: [...new Set([...own, ...ids(members, u.userId)])].sort((a, b) => a - b),
      };
    });
  }

  async findOne(id: number) {
    const user = await this.usersRepo.findOne({ where: { userId: id } });
    if (!user) throw new NotFoundException('계정을 찾을 수 없습니다');
    return user;
  }

  async findByUsername(username: string) {
    const user = await this.usersRepo.findOne({ where: { username } });
    if (!user) throw new NotFoundException('계정을 찾을 수 없습니다');
    return user;
  }

  async create(dto: CreateUserDto) {
    await this.assertUsernameFree(dto.username);
    let user: User;
    try {
      user = await this.usersRepo.save(
        this.usersRepo.create({ username: dto.username, role: dto.role, password: sha256Hex(dto.password) }),
      );
    } catch (e) {
      if ((e as { code?: string }).code === '23505') throw new ConflictException('이미 쓰는 아이디입니다');
      throw e;
    }
    if (dto.role !== 'admin' && dto.buildingIds?.length) await this.setBuildings(user.userId, dto.buildingIds);
    return this.findOne(user.userId);
  }

  /** actorId = 지금 로그인한 관리자 — 자기 권한을 낮추거나 마지막 관리자를 없애면 아무도 계정을 못 고친다. */
  async update(id: number, dto: UpdateUserDto, actorId: number) {
    const target = await this.findOne(id);
    if (dto.role && dto.role !== target.role && target.role === 'admin') {
      if (id === actorId) throw new BadRequestException('내 권한은 낮출 수 없습니다. 다른 관리자에게 부탁하세요');
      await this.assertNotLastAdmin();
    }
    if (dto.username && dto.username !== target.username) await this.assertUsernameFree(dto.username, id);
    const patch: Partial<User> = {};
    if (dto.username) patch.username = dto.username;
    if (dto.role) patch.role = dto.role;
    try {
      if (Object.keys(patch).length) await this.usersRepo.update({ userId: id }, patch);
    } catch (e) {
      if ((e as { code?: string }).code === '23505') throw new ConflictException('이미 쓰는 아이디입니다');
      throw e;
    }
    // 비밀번호를 새로 정하면 그 계정의 다른 로그인은 끊긴다(다시 로그인)
    if (dto.password) await setPassword(this.usersRepo, id, dto.password);
    return this.findOne(id);
  }

  async remove(id: number, actorId: number) {
    const target = await this.findOne(id);
    if (id === actorId) throw new BadRequestException('내 계정은 여기서 지울 수 없습니다');
    if (target.role === 'admin') await this.assertNotLastAdmin();
    await this.usersRepo.delete({ userId: id });
    return { message: '계정을 지웠습니다' };
  }

  /** 볼 수 있는 건물을 이 목록으로 바꾼다(멤버). 소유한 건물(buildings.user_id)은 그대로 남는다. */
  async setBuildings(id: number, buildingIds: number[]) {
    await this.findOne(id);
    if (!this.migrations.isReady()) throw new BadRequestException('서버 준비가 덜 됐습니다. 잠시 뒤 다시 해 주세요');
    const want = [...new Set(buildingIds.map(Number))];
    if (want.length) {
      const found: { building_id: number }[] = await this.usersRepo.query(
        'SELECT building_id FROM buildings WHERE building_id = ANY($1::int[])',
        [want],
      );
      if (found.length !== want.length) throw new BadRequestException('없는 건물이 들어 있습니다');
    }
    await this.usersRepo.manager.transaction(async (m) => {
      await m.query(`DELETE FROM building_members WHERE user_id = $1 AND role <> 'owner'`, [id]);
      if (want.length) {
        await m.query(
          `INSERT INTO building_members (building_id, user_id, role)
           SELECT b, $1, 'member' FROM unnest($2::int[]) AS b
           ON CONFLICT DO NOTHING`,
          [id, want],
        );
      }
    });
    return (await this.findAll()).find((u) => u.userId === id);
  }

  private async assertUsernameFree(username: string, exceptId?: number) {
    const taken = await this.usersRepo.findOne({ where: { username } });
    if (taken && taken.userId !== exceptId) throw new ConflictException('이미 쓰는 아이디입니다');
  }

  private async assertNotLastAdmin() {
    const admins = await this.usersRepo.count({ where: { role: 'admin' } });
    if (admins <= 1) throw new BadRequestException('관리자가 한 명은 있어야 합니다');
  }
}
