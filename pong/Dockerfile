# Stage 1: Build the Java application
FROM maven:3.8.4-openjdk-11 AS builder

WORKDIR /app

# Copy pom.xml first for better layer caching
COPY pom.xml .

# Copy source code
COPY src src

# Build the application
RUN mvn clean package -DskipTests

# Stage 2: Create the runtime image
FROM openjdk:11-jdk-slim

WORKDIR /app

# Install curl for health checks and netcat for wait-for script
RUN apt-get update && apt-get install -y curl netcat-openbsd && rm -rf /var/lib/apt/lists/*

# Copy wait-for script
COPY wait-for-artemis.sh /usr/local/bin/wait-for-artemis.sh
RUN chmod +x /usr/local/bin/wait-for-artemis.sh

# Copy the built JAR from the builder stage
COPY --from=builder /app/target/pong-service-1.0.0.jar app.jar

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Create startup script that waits for Artemis then starts the application
RUN echo '#!/bin/bash\n\
echo "Starting pong service..."\n\
echo "Waiting for Artemis message queue..."\n\
/usr/local/bin/wait-for-artemis.sh\n\
if [ $? -eq 0 ]; then\n\
    echo "Artemis is ready, starting pong service..."\n\
    exec java -jar app.jar\n\
else\n\
    echo "Failed to connect to Artemis, exiting..."\n\
    exit 1\n\
fi' > /usr/local/bin/start-pong.sh && chmod +x /usr/local/bin/start-pong.sh

ENTRYPOINT ["/usr/local/bin/start-pong.sh"]
