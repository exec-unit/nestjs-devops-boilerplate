import { Test, TestingModule } from '@nestjs/testing'
import { AppController } from './app.controller.js'
import { HealthCheckService } from '@nestjs/terminus'

describe('AppController', () => {
  let controller: AppController

  beforeEach(async () => {
    const mockHealthService = {
      check: jest
        .fn()
        .mockResolvedValue({ status: 'ok', info: {}, error: {}, details: {} }),
    }

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [
        {
          provide: HealthCheckService,
          useValue: mockHealthService,
        },
      ],
    }).compile()

    controller = module.get<AppController>(AppController)
  })

  it('should be defined', () => {
    expect(controller).toBeDefined()
  })

  it('check() should return health status', async () => {
    const result = await controller.check()
    expect(result).toMatchObject({ status: 'ok' })
  })
})
