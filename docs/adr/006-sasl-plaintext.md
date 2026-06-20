# ADR-006: SASL_PLAINTEXT for Redpanda Authentication

**Date:** 2025-12-19
**Status:** Accepted
**Deciders:** Project Lead

## Context

Redpanda supports multiple security protocols for client authentication:

Available options:

- PLAINTEXT - no authentication, no encryption
- SASL_PLAINTEXT - authentication via SASL, no encryption
- SASL_SSL - authentication via SASL, TLS encryption
- SSL - TLS encryption, certificate-based authentication

Deployment scenarios:

- local-dev: developers connect to shared-dev Redpanda over the internet (port 19092)
- shared-dev: Redpanda exposed externally for local developers
- stage/prod: Redpanda internal-only (port 9092), no external access

## Decision

Use SASL_PLAINTEXT (SASL/SCRAM-SHA-256 authentication without TLS encryption).

## Rationale

### Why SASL_PLAINTEXT

Network Topology:

shared-dev (external port):

- Only environment with external Redpanda access
- Contains test data only (no production or sensitive data)
- Used for development and testing
- Acceptable risk: credentials exposed in transit

stage/prod (internal-only):

- Redpanda port 9092 not exposed externally
- Communication only within Docker network
- Firewall blocks external access
- TLS security benefit exists but risk profile acceptable for current scope

Operational Complexity vs Security Benefit:

TLS Certificate Management Requirements:

- Certificate generation and rotation automation
- CA certificate distribution to all microservices
- Truststore/keystore management in containers
- Volume mounts for certificate files
- Certificate expiration monitoring
- Debugging TLS handshake failures

Time Investment:

- Initial setup: ~1 day (certificate generation, NestJS configuration, testing, troubleshooting)
- Ongoing maintenance: certificate rotation (quarterly), monitoring
- Focus shift from application architecture to certificate operations

NestJS Configuration Comparison:

SASL_PLAINTEXT (current):

```typescript
sasl: {
  mechanism: 'scram-sha-256',
  username: process.env.REDPANDA_USERNAME,
  password: process.env.REDPANDA_PASSWORD,
}
```

SASL_SSL (alternative, additional configuration required):

```typescript
sasl: {
  mechanism: 'scram-sha-256',
  username: process.env.REDPANDA_USERNAME,
  password: process.env.REDPANDA_PASSWORD,
},
ssl: {
  rejectUnauthorized: true,
  ca: fs.readFileSync('/path/to/ca.crt'),
  cert: fs.readFileSync('/path/to/client.crt'),
  key: fs.readFileSync('/path/to/client.key'),
}
```

Additional operational burden:

- Certificate files in Docker images or mounted volumes
- Environment-specific certificate paths per container
- Certificate validation configuration
- TLS version and cipher suite management

### Risk Assessment

shared-dev External Exposure:

- Threat: credential interception during transit
- Likelihood: low (requires active network monitoring)
- Impact: access to test environment only
- Risk Acceptance:
  - Test data only, no sensitive information
  - Credential rotation policy in place
  - Optional IP allowlist can further reduce exposure

stage/prod Internal Communication:

- Threat: network sniffing within Docker network
- Likelihood: very low (requires host compromise)
- Impact: if host is compromised, TLS provides limited additional protection
- Risk Acceptance:
  - Attacker with host access has filesystem and memory access
  - TLS protects data in transit but not at rest or in memory
  - Defense-in-depth focuses on host hardening (SSH keys, fail2ban, firewall, minimal attack surface)

### Security Model Analysis

Current Approach - Network Boundary Security:

- External firewall blocks unauthorized access
- Docker network isolation for internal communication
- SASL authentication prevents unauthorized clients
- Host hardening as primary security layer

Alternative - Zero Trust with mTLS:

Requirements:

- Mutual TLS between all microservices
- Certificate authority infrastructure
- Certificate lifecycle management (generation, distribution, rotation, revocation)
- Service mesh (Istio/Linkerd) or manual certificate management
- TLS configuration for all service-to-service calls

Operational Impact:

- Initial implementation: 2-3 days (CA setup, certificate distribution, service configuration, testing)
- Ongoing maintenance: certificate rotation, monitoring, troubleshooting
- Increased complexity in debugging (encrypted traffic, certificate validation errors)

Trade-off Analysis:

Security benefit exists but is limited in current architecture:

- Single-host deployment: network boundary already defined
- Host compromise defeats TLS (attacker has memory/filesystem access)
- No multi-tenant requirements
- No regulatory compliance requirements for encryption in transit

Operational cost is significant:

- Certificate management complexity
- Debugging overhead
- Maintenance burden
- Focus shift from application features to security infrastructure

Decision: Accept current risk profile, implement SASL_PLAINTEXT now with a defined migration path to SASL_SSL.

## Implementation

### Redpanda Configuration

```yaml
redpanda:
  command:
    - redpanda start
    - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:19092
    - --advertise-kafka-addr internal://redpanda:9092,external://${SHARED_DEV_HOST}:19092
  environment:
    REDPANDA_SUPERUSER_PASSWORD: ${REDPANDA_SUPERUSER_PASSWORD}
```

### Bootstrap Script

```bash
rpk cluster config set superusers [admin]
rpk acl user create admin -p "${REDPANDA_SUPERUSER_PASSWORD}" \
  --mechanism SCRAM-SHA-256
```

### NestJS Configuration

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

Operational Simplicity:

- No certificate management
- No truststore/keystore distribution
- Simpler debugging (no TLS handshake issues)
- Faster development iteration

Authentication Enabled:

- SASL/SCRAM-SHA-256 prevents unauthorized access
- Credentials required for all connections
- ACLs can be configured per user

Performance:

- No TLS encryption overhead
- Lower CPU usage
- Lower latency

### Negative

Credentials in Transit (shared-dev only):

- Credentials visible if network traffic is intercepted
- Mitigation: test data only, regular credential rotation

Not Zero Trust:

- Assumes VDS network is trusted
- Mitigation: VDS hardening, firewall, SSH key auth only

### Migration Path

If security requirements change:

1. Generate TLS certificates (Let's Encrypt or self-signed CA)
2. Update Redpanda configuration to enable TLS listeners
3. Distribute CA certificate to all microservices
4. Update NestJS Kafka client configuration to include `ssl` options
5. Test and deploy

Estimated effort: 1 day for single-host deployment

## Related Decisions

- [ADR-002: Redpanda for Event Streaming](002-redpanda.md)
- [ADR-004: Git as Single Source of Truth](004-git-as-single-source-of-truth.md)

## References

- [Redpanda Security Documentation](https://docs.redpanda.com/docs/security/)
- [Kafka SASL/SCRAM Authentication](https://kafka.apache.org/documentation/#security_sasl_scram)
- [KafkaJS SSL/SASL Configuration](https://kafka.js.org/docs/configuration#ssl)
