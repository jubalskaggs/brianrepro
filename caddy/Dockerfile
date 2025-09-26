FROM caddy:2-builder AS builder

# Build Caddy with any plugins you need
RUN xcaddy build \
    --with github.com/caddyserver/caddy/v2

FROM debian:11-slim

# Install curl and other dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Copy Caddy binary from builder
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# Copy the Caddyfile into the image
COPY Caddyfile /etc/caddy/Caddyfile

# Copy the index.html file
COPY index.html /srv/index.html


# Copy log forwarder script
COPY log-forwarder.py /usr/local/bin/log-forwarder.py
RUN chmod +x /usr/local/bin/log-forwarder.py

# Create directories for Caddy data and config
RUN mkdir -p /data /config /srv /var/log/caddy

# Create a non-root user
RUN groupadd --system --gid 1001 caddy \
    && useradd --system --uid 1001 --gid caddy --home-dir /data --shell /bin/bash caddy

# Set ownership
RUN chown -R caddy:caddy /data /config /var/log/caddy

# Expose ports
EXPOSE 80 443

# Create startup script that starts Caddy and log forwarder
RUN echo '#!/bin/bash\n\
echo "Starting Caddy reverse proxy..."\n\
echo "Clearing ALL cached configuration and data..."\n\
rm -rf /data/.config/caddy 2>/dev/null || true\n\
rm -rf /data/.local/share/caddy 2>/dev/null || true\n\
rm -rf /data/caddy 2>/dev/null || true\n\
echo "Starting log forwarder..."\n\
/usr/local/bin/log-forwarder.py &\n\
echo "Starting Caddy..."\n\
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile' > /usr/local/bin/start-caddy.sh && chmod +x /usr/local/bin/start-caddy.sh

USER caddy

CMD ["/usr/local/bin/start-caddy.sh"]
