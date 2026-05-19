import { Module } from '@nestjs/common'
import { AppController } from './app.controller.js'
import { TerminusModule } from '@nestjs/terminus'

@Module({
  imports: [TerminusModule],
  controllers: [AppController],
  providers: [],
})
export class AppModule {}
