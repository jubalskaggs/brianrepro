FROM caddy:2-builder AS builder

# Build Caddy with any plugins you need
RUN caddy-builder \
    github.com/caddyserver/caddy/v2

FROM debian:11-slim

# Install curl and other dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy Caddy binary from builder
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# Copy the Caddyfile into the image
COPY Caddyfile /etc/caddy/Caddyfile

# Copy wait-for script
COPY wait-for-services.sh /usr/local/bin/wait-for-services.sh
RUN chmod +x /usr/local/bin/wait-for-services.sh

# Create directories for Caddy data and config
RUN mkdir -p /data /config

# Create a non-root user
RUN groupadd --system --gid 1001 caddy \
    && useradd --system --uid 1001 --gid caddy --home-dir /data --shell /bin/bash caddy

# Set ownership
RUN chown -R caddy:caddy /data /config /usr/local/bin/wait-for-services.sh

# Expose ports
EXPOSE 80 443

# Create startup script that waits for services then starts Caddy
RUN echo '#!/bin/bash\n\
echo "Starting Caddy reverse proxy..."\n\
echo "Waiting for ping and pong services..."\n\
/usr/local/bin/wait-for-services.sh\n\
if [ $? -eq 0 ]; then\n\
    echo "Services are ready, starting Caddy..."\n\
    exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile\n\
else\n\
    echo "Failed to connect to services, exiting..."\n\
    exit 1\n\
fi' > /usr/local/bin/start-caddy.sh && chmod +x /usr/local/bin/start-caddy.sh

USER caddy

CMD ["/usr/local/bin/start-caddy.sh"]
