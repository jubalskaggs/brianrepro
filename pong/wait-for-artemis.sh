#!/bin/bash

# Wait for Artemis message queue to be ready
# This script waits for Artemis to be available on port 61616

ARTEMIS_HOST=${MQ_HOST:-artemis}
ARTEMIS_PORT=${MQ_PORT:-61616}
MAX_ATTEMPTS=30
ATTEMPT=1

echo "Waiting for Artemis message queue at $ARTEMIS_HOST:$ARTEMIS_PORT..."

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Checking Artemis connection..."
    
    # Try to connect to Artemis port
    if nc -z $ARTEMIS_HOST $ARTEMIS_PORT 2>/dev/null; then
        echo "✅ Artemis is ready at $ARTEMIS_HOST:$ARTEMIS_PORT"
        exit 0
    fi
    
    echo "⏳ Artemis not ready yet, waiting 2 seconds..."
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
done

echo "❌ ERROR: Artemis did not become available after $MAX_ATTEMPTS attempts"
echo "   This usually means Artemis is not running or not accessible"
exit 1
