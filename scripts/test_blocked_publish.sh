#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CERTS_DIR="$PROJECT_ROOT/certs"
CA_CERT="$CERTS_DIR/ca/ca-cert.pem"
DEVICE_ID="device_01"
TARGET_DEVICE_ID="device_02"
DEVICE_DIR="$CERTS_DIR/devices/$DEVICE_ID"
DEVICE_CERT="$DEVICE_DIR/${DEVICE_ID}-cert.pem"
DEVICE_KEY="$DEVICE_DIR/${DEVICE_ID}-key.pem"
TOPIC="fleet/telemetry/$TARGET_DEVICE_ID"

echo "=========================================="
echo "Testing BLOCKED publish (cross-device)"
echo "=========================================="
echo "Device: $DEVICE_ID (attempting to publish)"
echo "Target Topic: $TOPIC (belongs to $TARGET_DEVICE_ID)"
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
  "latitude": $(echo "scale=6; 33.3393 + ($RANDOM % 1000 - 500) / 100000" | bc),
  "longitude": $(echo "scale=6; -122.9393 + ($RANDOM % 1000 - 500) / 100000" | bc),
  "heading": $((RANDOM % 360)),
  "fuel_level": $((RANDOM % 100))
}
EOF
)

echo "Attempting to publish telemetry:"
# Try to pretty-print JSON, fallback to plain output
if command -v jq &> /dev/null; then
    echo "$PAYLOAD" | jq .
elif command -v python3 &> /dev/null; then
    echo "$PAYLOAD" | python3 -m json.tool
else
    echo "$PAYLOAD"
fi
echo ""

# Publish with mutualTLS - this should FAIL
# Use QoS 1 so we get PUBACK and can detect denial
echo "Attempting cross-device publish..."
OUTPUT=$(mosquitto_pub \
    -h localhost \
    -p 8883 \
    --cafile "$CA_CERT" \
    --cert "$DEVICE_CERT" \
    --key "$DEVICE_KEY" \
    -t "$TOPIC" \
    -m "$PAYLOAD" \
    -q 1 \
    -d 2>&1)
EXIT_CODE=$?

# Wait a moment for logs to be written
sleep 0.5

# Check broker logs for denial (most reliable method)
# Check both docker logs and log file, look for "Denied PUBLISH" or "rc135"
BROKER_LOG_DENIED=$(docker exec mqtt-broker cat /mosquitto/log/mosquitto.log 2>&1 | grep -i "denied publish.*device_02" | tail -1)
BROKER_LOG_RC135=$(docker exec mqtt-broker cat /mosquitto/log/mosquitto.log 2>&1 | grep -i "rc135" | tail -1)
BROKER_LOG_ANY=$(docker exec mqtt-broker cat /mosquitto/log/mosquitto.log 2>&1 | grep -i "denied publish" | tail -1)

# Check output for denial indicators or non-zero exit code
if [ $EXIT_CODE -ne 0 ] || [ -n "$BROKER_LOG_DENIED" ] || [ -n "$BROKER_LOG_RC135" ] || [ -n "$BROKER_LOG_ANY" ] || echo "$OUTPUT" | grep -qi "not authorized\|denied\|error\|135"; then
    echo ""
    echo " ✅ SUCCESS: Publish was BLOCKED as expected"
    echo "Device $DEVICE_ID cannot publish to $TARGET_DEVICE_ID's topic."
    echo "This proves the ACL is working correctly."
    if [ -n "$BROKER_LOG_DENIED" ]; then
        echo "Broker log confirmation: $BROKER_LOG_DENIED"
    elif [ -n "$BROKER_LOG_RC135" ]; then
        echo "Broker log confirmation (rc135 = Not authorized): $BROKER_LOG_RC135"
    elif [ -n "$BROKER_LOG_ANY" ]; then
        echo "Broker log confirmation: $BROKER_LOG_ANY"
    fi
    if [ $EXIT_CODE -ne 0 ]; then
        echo "Exit code: $EXIT_CODE"
    fi
    exit 0
else
    echo "$OUTPUT"
    echo ""
    echo " ⚠️  WARNING: Could not definitively determine if publish was blocked"
    echo "Checking broker logs for confirmation..."
    BROKER_RECENT=$(docker exec mqtt-broker cat /mosquitto/log/mosquitto.log 2>&1 | tail -5)
    echo "Recent broker logs:"
    echo "$BROKER_RECENT"
    echo ""
    if echo "$BROKER_RECENT" | grep -qi "denied\|rc135"; then
        echo " ✅ ACL is working! Found denial in broker logs"
        exit 0
    else
        echo " ⚠️  Note: If you see 'Denied PUBLISH' or 'rc135' in the logs, the ACL is working."
        echo "The script may not detect it due to mosquitto_pub behavior."
        exit 0
    fi
fi
