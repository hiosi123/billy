import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Floor } from './floor.entity';
import { FloorsService } from './floors.service';
import { FloorsController } from './floors.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Floor])],
  providers: [FloorsService],
  controllers: [FloorsController],
  exports: [FloorsService, TypeOrmModule],
})
export class FloorsModule {}
