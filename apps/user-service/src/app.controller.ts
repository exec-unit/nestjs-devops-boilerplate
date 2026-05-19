import { Controller, Get } from '@nestjs/common'
import { HealthCheckService, HealthCheck } from '@nestjs/terminus'

/**
 * Basic health controller to demonstrate working NestJS process
 */
@Controller('health')
export class AppController {
  constructor(private health: HealthCheckService) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([() => ({ 'user-service': { status: 'up' } })])
  }
}
