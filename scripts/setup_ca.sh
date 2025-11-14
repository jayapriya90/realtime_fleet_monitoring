#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CERTS_DIR="$PROJECT_ROOT/certs"
CA_DIR="$CERTS_DIR/ca"
BROKER_DIR="$CERTS_DIR/broker"
DEVICES_DIR="$CERTS_DIR/devices"

echo "Setting up Certificate Authority and certificates..."

# Create directories
mkdir -p "$CA_DIR" "$BROKER_DIR" "$DEVICES_DIR"

# Generate CA private key
if [ ! -f "$CA_DIR/ca-key.pem" ]; then
    echo "Generating CA private key..."
    openssl genrsa -out "$CA_DIR/ca-key.pem" 4096
fi

# Generate CA certificate
if [ ! -f "$CA_DIR/ca-cert.pem" ]; then
    echo "Generating CA certificate..."
    openssl req -new -x509 -days 3650 -key "$CA_DIR/ca-key.pem" \
        -out "$CA_DIR/ca-cert.pem" \
        -subj "/C=IN/ST=Maharashtra/L=Mumbai/O=FleetMonitoring/CN=FleetMonitoring-CA"
fi

# Generate broker certificate
echo "Generating broker certificate..."
if [ ! -f "$BROKER_DIR/broker-key.pem" ]; then
    openssl genrsa -out "$BROKER_DIR/broker-key.pem" 2048
fi

if [ ! -f "$BROKER_DIR/broker.csr" ]; then
    openssl req -new -key "$BROKER_DIR/broker-key.pem" \
        -out "$BROKER_DIR/broker.csr" \
        -subj "/C=IN/ST=Maharashtra/L=Mumbai/O=FleetMonitoring/CN=mqtt-broker"
fi

if [ ! -f "$BROKER_DIR/broker-cert.pem" ]; then
    openssl x509 -req -in "$BROKER_DIR/broker.csr" \
        -CA "$CA_DIR/ca-cert.pem" \
        -CAkey "$CA_DIR/ca-key.pem" \
        -CAcreateserial \
        -out "$BROKER_DIR/broker-cert.pem" \
        -days 365 \
        -extensions v3_req \
        -extfile <(cat <<EOF
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
DNS.2 = mqtt-broker
IP.1 = 127.0.0.1
EOF
)
fi

# Generate 10 device certificates
for i in $(seq -f "%02g" 1 10); do
    DEVICE_ID="device_$i"
    DEVICE_DIR="$DEVICES_DIR/$DEVICE_ID"
    mkdir -p "$DEVICE_DIR"
    
    echo "Generating certificate for $DEVICE_ID..."
    
    if [ ! -f "$DEVICE_DIR/${DEVICE_ID}-key.pem" ]; then
        openssl genrsa -out "$DEVICE_DIR/${DEVICE_ID}-key.pem" 2048
    fi
    
    if [ ! -f "$DEVICE_DIR/${DEVICE_ID}.csr" ]; then
        openssl req -new -key "$DEVICE_DIR/${DEVICE_ID}-key.pem" \
            -out "$DEVICE_DIR/${DEVICE_ID}.csr" \
            -subj "/C=IN/ST=Maharashtra/L=Mumbai/O=FleetMonitoring/CN=$DEVICE_ID"
    fi
    
    if [ ! -f "$DEVICE_DIR/${DEVICE_ID}-cert.pem" ]; then
        openssl x509 -req -in "$DEVICE_DIR/${DEVICE_ID}.csr" \
            -CA "$CA_DIR/ca-cert.pem" \
            -CAkey "$CA_DIR/ca-key.pem" \
            -CAcreateserial \
            -out "$DEVICE_DIR/${DEVICE_ID}-cert.pem" \
            -days 365 \
            -extensions v3_req \
            -extfile <(cat <<EOF
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = $DEVICE_ID
DNS.2 = $DEVICE_ID.fleet.local
EOF
)
    fi
    
    # Create combined cert+key for client use (some Message Queuing Telemetry Transport clients need this)
    if [ ! -f "$DEVICE_DIR/${DEVICE_ID}-fullchain.pem" ]; then
        cat "$DEVICE_DIR/${DEVICE_ID}-cert.pem" "$CA_DIR/ca-cert.pem" > "$DEVICE_DIR/${DEVICE_ID}-fullchain.pem"
    fi
done

echo ""
echo "Certificate setup complete!"
echo "CA certificate: $CA_DIR/ca-cert.pem"
echo "Broker certificate: $BROKER_DIR/broker-cert.pem"
echo "Device certificates: $DEVICES_DIR/device_*/"
echo ""
echo "Next steps:"
echo "1. Review the Mosquitto configuration in mosquitto.conf"
echo "2. Start the broker: docker-compose up -d"
echo "3. Test allowed publish with: ./scripts/test_allowed_publish.sh"
echo "4. Test blocked publish with: ./scripts/test_blocked_publish.sh"
