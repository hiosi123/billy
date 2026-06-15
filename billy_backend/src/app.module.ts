import { Module, NestModule, MiddlewareConsumer } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LoggerMiddleware } from './common/logger.middleware';
import { databaseConfigFactory } from './config/database.config';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { BuildingsModule } from './buildings/buildings.module';
import { FloorsModule } from './floors/floors.module';
import { RoomsModule } from './rooms/rooms.module';
import { BuildingFeesModule } from './building-fees/building-fees.module';
import { BillHistoriesModule } from './bill-histories/bill-histories.module';
import { CalcInputsModule } from './calc-inputs/calc-inputs.module';
import { UploadModule } from './upload/upload.module';
import { BillsModule } from './bills/bills.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({ inject: [ConfigService], useFactory: databaseConfigFactory }),
    AuthModule,
    UsersModule,
    BuildingsModule,
    FloorsModule,
    RoomsModule,
    BuildingFeesModule,
    // ⚠️ 'bills/histories', 'bills/calc-inputs' 가 'bills/:id' 보다 먼저 매칭되도록 BillsModule 앞에 둔다.
    BillHistoriesModule,
    CalcInputsModule,
    UploadModule,
    BillsModule,
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggerMiddleware).forRoutes('*');
  }
}
