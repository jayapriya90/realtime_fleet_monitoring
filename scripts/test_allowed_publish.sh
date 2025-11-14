#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CERTS_DIR="$PROJECT_ROOT/certs"
CA_CERT="$CERTS_DIR/ca/ca-cert.pem"
DEVICE_ID="device_01"
DEVICE_DIR="$CERTS_DIR/devices/$DEVICE_ID"
DEVICE_CERT="$DEVICE_DIR/${DEVICE_ID}-cert.pem"
DEVICE_KEY="$DEVICE_DIR/${DEVICE_ID}-key.pem"
TOPIC="fleet/telemetry/$DEVICE_ID"

echo "=========================================="
echo "Testing ALLOWED publish"
echo "=========================================="
echo "Device: $DEVICE_ID"
echo "Topic: $TOPIC"
echo ""

# Check if mosquitto_pub is available
if ! command -v mosquitto_pub &> /dev/null; then
    echo "Error: mosquitto_pub not found. Install mosquitto-clients:"
    echo "  macOS: brew install mosquitto"
    echo "  Ubuntu: sudo apt-get install mosquitto-clients"
    exit 1
fi

# Create sample telemetry payload
TIMESTAMP=$(date +%s)
PAYLOAD=$(cat <<EOF
{
  "device_id": "$DEVICE_ID",
  "timestamp": $TIMESTAMP,
  "speed": $((RANDOM % 80 + 20)),
  "latitude": $(echo "scale=6; 33.3339 + ($RANDOM % 1000 - 500) / 100000" | bc),
  "longitude": $(echo "scale=6; -122.9393 + ($RANDOM % 1000 - 500) / 100000" | bc),
  "heading": $((RANDOM % 360)),
  "fuel_level": $((RANDOM % 100))
}
EOF
)

echo "Publishing telemetry:"
# Try to pretty-print JSON, fallback to plain output
if command -v jq &> /dev/null; then
    echo "$PAYLOAD" | jq .
elif command -v python3 &> /dev/null; then
    echo "$PAYLOAD" | python3 -m json.tool
else
    echo "$PAYLOAD"
fi
echo ""

# Publish with mutual TLS
# Use QoS 1 so we get PUBACK and can detect denial
if mosquitto_pub \
    -h localhost \
    -p 8883 \
    --cafile "$CA_CERT" \
    --cert "$DEVICE_CERT" \
    --key "$DEVICE_KEY" \
    -t "$TOPIC" \
    -m "$PAYLOAD" \
    -q 1 \
    -d; then
    echo ""
    echo " ✅ SUCCESS: Message published to $TOPIC"
    echo "This publish was ALLOWED because device_01 is publishing to its own topic."
else
    echo ""
    echo " ❌ FAILED: Publish was rejected"
    exit 1
fi

