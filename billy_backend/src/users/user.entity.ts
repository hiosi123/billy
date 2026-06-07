import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

export type UserRole = 'admin' | 'manager' | 'viewer';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn({ name: 'user_id' })
  userId: number;

  @Column({ name: 'username', length: 64, unique: true })
  username: string;

  /** SHA-256 hex. select:false 로 기본 조회에서 제외, 로그인 시 명시적으로 가져온다. */
  @Column({ name: 'password', length: 255, select: false })
  password: string;

  // Postgres 네이티브 enum 대신 varchar + DB CHECK 제약으로 역할을 제한한다.
  @Column({ name: 'role', type: 'varchar', length: 16, default: 'viewer' })
  role: UserRole;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
