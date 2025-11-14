#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CERTS_DIR="$PROJECT_ROOT/certs"

echo "====================================================================="
echo "Verifying Secure Message Queuing Telemetry Transport Ingress Setup"
echo "====================================================================="
echo ""

# Check if certificates exist
echo "1. Checking certificates..."
if [ ! -f "$CERTS_DIR/ca/ca-cert.pem" ]; then
    echo "   ❌ CA certificate not found. Run ./scripts/setup_ca.sh first."
    exit 1
fi
echo "   ✅ Self-signed CA certificate found"

if [ ! -f "$CERTS_DIR/broker/broker-cert.pem" ]; then
    echo "   ❌ Mosquitto Message Queuing Telemetry Transport Broker certificate not found. Run ./scripts/setup_ca.sh first."
    exit 1
fi
echo "   ✅ Mosquitto Message Queuing Telemetry Transport Broker certificate found"

DEVICE_COUNT=0
for i in $(seq -f "%02g" 1 10); do
    DEVICE_ID="device_$i"
    if [ -f "$CERTS_DIR/devices/$DEVICE_ID/${DEVICE_ID}-cert.pem" ]; then
        DEVICE_COUNT=$((DEVICE_COUNT + 1))
    fi
done

if [ $DEVICE_COUNT -eq 10 ]; then
    echo "   ✅ All 10 device certificates found"
else
    echo "   ❌ Only $DEVICE_COUNT/10 device certificates found. Run ./scripts/setup_ca.sh first."
    exit 1
fi

# Check if Mosquitto broker is running
echo ""
echo "2. Checking Mosquitto broker..."
if docker ps | grep -q mqtt-broker; then
    echo "   ✅ Mosquitto Message Queuing Telemetry Transport broker is running"
    BROKER_RUNNING=true
else
    echo "   ⚠️  Mosquitto Message Queuing Telemetry Transport broker is not running. Start it with: docker-compose up -d"
    BROKER_RUNNING=false
fi

# Check configuration files
echo ""
echo "3. Checking configuration files..."
if [ -f "$PROJECT_ROOT/mosquitto.conf" ]; then
    echo "   ✅ mosquitto.conf found"
else
    echo "   ❌ mosquitto.conf not found"
    exit 1
fi

if [ -f "$PROJECT_ROOT/acl.conf" ]; then
    echo "   ✅ acl.conf found"
else
    echo "   ❌ acl.conf not found"
    exit 1
fi

# Summary
echo ""
echo "================================================================================="
echo "Secure Message Queuing Telemetry Transport Ingress Setup Verification Summary"
echo "================================================================================="
echo "Certificate Authority and Broker Certificates: ✅ Complete"
echo "Device Certificates: ✅ Complete"
echo "Mosquitto Broker Configuration: ✅ Complete"
echo "Devices Acesss Control Configuration: ✅ Complete"
if [ "$BROKER_RUNNING" = true ]; then
    echo "Mosquitto Broker Status: ✅ Running"
    echo ""
    echo "Ready to test!"
    echo "  - Test allowed publish: ./scripts/test_allowed_publish.sh"
    echo "  - Test blocked publish: ./scripts/test_blocked_publish.sh"
else
    echo "Mosquitto Broker Status: ⚠️  Not running"
    echo ""
    echo "Start the broker with: docker-compose up -d"
fi
