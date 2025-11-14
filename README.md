# Realtime Fleet Monitoring - Secure Message Queuing Telemetry Transport Ingress

This project implements a secure Message Queuing Telemetry Transport ingress for truck telemetry with mutual TLS (mTLS) authentication and per-device access control.

## Architecture

- **Message Queuing Telemetry Transport Broker**: Mosquitto with mTLS enabled
- **Certificate Authority**: Self-signed CA for device certificates
- **Topic Scheme**: `fleet/telemetry/<device_id>`
- **ACLs**: Each device can only publish to its own topic

## Quick Start

### Prerequisites

- Docker and Docker Compose
- OpenSSL (for certificate generation)
- Python 3.8 or newer version with pip (optional)
- OR mosquitto-clients (for shell-based test scripts)

### Setup Steps

1. **Generate certificates:**
   ```bash
   ./scripts/setup_ca.sh
   ```
   This creates:
   - A Certificate Authority (CA)
   - Broker certificate signed by CA
   - 10 device certificates (device_01 through device_10) with unique CN/SAN

2. **Start the Mosquitto broker:**
   ```bash
   docker-compose up -d
   ```
   The broker will listen on port 8883 with mutualTLS enabled.

3. **Verify broker is running:**
   ```bash
   docker logs mqtt-broker
   ```

### Testing

#### Option 1: Python Script (Recommended)

Install dependencies:
```bash
pip install -r requirements.txt
```

Test allowed publish (device_01 to its own topic):
```bash
python3 scripts/test_publish.py --device device_01
```

Test blocked publish (device_01 attempting to publish to device_02's topic):
```bash
python3 scripts/test_publish.py --device device_01 --target device_02 --blocked
```

#### Option 2: Shell Scripts

Test allowed publish:
```bash
./scripts/test_allowed_publish.sh
```

Test blocked publish:
```bash
./scripts/test_blocked_publish.sh
```

### Verification

The blocked publish test should demonstrate that:
- Device authentication succeeds (mTLS connection established)
- Authorization fails (ACL blocks cross-device publish)
- Error message indicates permission denied

## Certificate Structure

- `certs/ca/` - Certificate Authority files
- `certs/broker/` - Message Queuing broker certificate
- `certs/devices/` - Device certificates (device_01 through device_10)

## Device IDs

- device_01 through device_10

Each device can only publish to `fleet/telemetry/<its_own_device_id>`.

