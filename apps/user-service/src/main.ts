import { NestFactory } from '@nestjs/core'
import { AppModule } from './app.module.js'
import pino from 'pino'

async function bootstrap() {
  const pinoOptions: pino.LoggerOptions = {
    level: process.env['LOG_LEVEL'] || 'info',
  }

  if (process.env['NODE_ENV'] !== 'production') {
    pinoOptions.transport = { target: 'pino-pretty' }
  }

  const logger = pino(pinoOptions)

  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  })

  app.enableShutdownHooks()

  const port = process.env['SERVER_PORT'] || 8080
  await app.listen(port)
  logger.info(`User Service listening on port ${String(port)}`)
}

void bootstrap()
