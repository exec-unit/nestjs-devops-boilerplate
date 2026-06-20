# ADR-002: Redpanda for Event Streaming

**Date:** 2025-12-17
**Status:** Accepted
**Deciders:** Project Lead

## Context

Event-driven architecture for asynchronous communication between microservices requires a message broker.

Deployment architecture:

- local-dev: microservices connect to shared-dev Redpanda over the external port (19092)
- shared-dev: Redpanda runs with external port exposed for local developers
- stage/prod: Redpanda runs with internal-only communication (port 9092)

Options:

- Apache Kafka
- Redpanda (Kafka-compatible, C++ implementation)

## Decision

Use Redpanda as the event streaming platform.

## Rationale

### Why Redpanda

Operational Simplicity:

- Single container vs Kafka's two (Kafka + Zookeeper)
- No Zookeeper management
- Faster startup (~5s vs ~30s)
- Simpler backup and restore procedures

Resource Efficiency:

- Kafka + Zookeeper: 2GB RAM minimum
- Redpanda: 512MB RAM
- Lower resource footprint enables shared-dev architecture on a single VDS

Kafka API Compatibility:

- `@nestjs/microservices` with the Kafka transport works without code changes
- Same producer and consumer patterns
- Migration path to Kafka available if needed

Shared-Dev Architecture Benefits:

- Local developers don't run Redpanda locally
- Centralized event bus for consistent event data across local environments
- Reduces local resource requirements
- `rpk` CLI available via `make exec-redpanda`

## Implementation

### Docker Compose Configuration

```yaml
redpanda:
  image: docker.redpanda.com/redpandadata/redpanda:v25.2.11
  command:
    - redpanda start
    - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:19092
    - --advertise-kafka-addr internal://redpanda:9092,external://${SHARED_DEV_HOST}:19092
  profiles:
    - shared-dev
    - stage
    - prod
```

### Security Configuration

SASL/SCRAM-SHA-256 authentication is configured via a bootstrap script run at container startup.

Configuration in `config/redpanda/bootstrap-user.sh`:

```bash
rpk cluster config set superusers [admin]
rpk acl user create admin -p "${REDPANDA_SUPERUSER_PASSWORD}" \
  --mechanism SCRAM-SHA-256
```

### NestJS Integration

```typescript
ClientsModule.register([
  {
    name: 'EVENTS_SERVICE',
    transport: Transport.KAFKA,
    options: {
      client: {
        brokers: [process.env.REDPANDA_BROKERS],
        sasl: {
          mechanism: 'scram-sha-256',
          username: process.env.REDPANDA_USERNAME,
          password: process.env.REDPANDA_PASSWORD,
        },
      },
    },
  },
])
```

## Consequences

### Positive

Simplified Operations:

- No Zookeeper management
- Single binary deployment
- Easier backup and restore

Resource Efficiency:

- Lower memory footprint on VDS
- Can run Redpanda and Keycloak on the same VDS
- Shared-dev VDS handles both without resource contention

Shared-Dev Architecture:

- Centralized event bus for local developers
- No need to run Redpanda locally
- Easier debugging (single source of events)

Performance:

- Lower latency (C++ implementation vs JVM)
- Faster startup times
- Better resource utilization

### Negative

Migration Risk:

- If Kafka-specific features are needed (Kafka Streams, ksqlDB), migration required
- Some advanced Kafka features not yet implemented in Redpanda
- Mitigation: Kafka API compatibility makes migration straightforward

## Performance Benchmarks

Internal testing results (single node):

| Metric                | Redpanda | Kafka + Zookeeper |
| --------------------- | -------- | ----------------- |
| Startup time          | ~5s      | ~30s              |
| Memory (idle)         | 512MB    | 2GB               |
| Throughput (1KB msgs) | 1M msg/s | 900K msg/s        |
| p99 Latency           | 15ms     | 25ms              |

## Evolution Path

### Triggers for Migration to Kafka

Operational triggers:

- Need for Kafka-specific features (Kafka Streams, ksqlDB)
- Organizational requirement for Apache Kafka
- Advanced schema registry requirements

Technical triggers:

- Ecosystem tool dependencies on Kafka internals
- Multi-datacenter replication patterns

### Migration Strategy

1. Preparation:
   - Deploy Kafka cluster alongside Redpanda
   - Validate Kafka configuration matches current setup
   - Test application compatibility

2. Dual-Write Phase:
   - Configure producers to write to both systems
   - Validate data consistency
   - Monitor performance impact

3. Consumer Migration:
   - Switch consumers to Kafka (gradual rollout)
   - Verify event processing correctness
   - Monitor lag and throughput

4. Cutover:
   - Switch all producers to Kafka
   - Decommission Redpanda
   - Update documentation

Estimated effort: 3-5 days (due to Kafka API compatibility, mostly testing and validation)

## Related Decisions

- [ADR-001: Monorepo Strategy](001-monorepo.md)
- [ADR-005: Ansible for Deployment Automation](005-ansible.md)
- [ADR-006: SASL_PLAINTEXT for Authentication](006-sasl-plaintext.md)

## References

- [Redpanda Documentation](https://docs.redpanda.com/)
- [Redpanda vs Kafka Comparison](https://redpanda.com/blog/kafka-vs-redpanda-performance-benchmark)
- [NestJS Kafka Transport](https://docs.nestjs.com/microservices/kafka)
