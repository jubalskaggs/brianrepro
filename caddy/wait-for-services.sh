#!/bin/bash

# Wait for ping and pong services to be ready
# This script waits for both services to be healthy

PING_HOST=${PING_HOST:-ping}
PONG_HOST=${PONG_HOST:-pong}
SERVICE_PORT=8080
MAX_ATTEMPTS=30
ATTEMPT=1

echo "Waiting for ping and pong services to be ready..."

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Checking services..."
    
    # Check if ping service is ready
    PING_READY=false
    if curl -f -s http://$PING_HOST:$SERVICE_PORT/actuator/health >/dev/null 2>&1; then
        PING_READY=true
        echo "✅ Ping service is ready"
    else
        echo "⏳ Ping service not ready yet"
    fi
    
    # Check if pong service is ready
    PONG_READY=false
    if curl -f -s http://$PONG_HOST:$SERVICE_PORT/actuator/health >/dev/null 2>&1; then
        PONG_READY=true
        echo "✅ Pong service is ready"
    else
        echo "⏳ Pong service not ready yet"
    fi
    
    # If both services are ready, exit successfully
    if [ "$PING_READY" = true ] && [ "$PONG_READY" = true ]; then
        echo "🎉 All services are ready!"
        exit 0
    fi
    
    echo "⏳ Waiting 3 seconds before next attempt..."
    sleep 3
    ATTEMPT=$((ATTEMPT + 1))
done

echo "❌ ERROR: Services did not become ready after $MAX_ATTEMPTS attempts"
echo "   Ping ready: $PING_READY"
echo "   Pong ready: $PONG_READY"
exit 1
