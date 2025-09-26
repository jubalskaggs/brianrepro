FROM apache/activemq-artemis:2.34.0

# make these directories so the artemis user can write to them
RUN mkdir -p /var/lib/artemis-instance/lib
RUN mkdir -p /var/lib/artemis-instance/etc

# Copy our dependencies for logback into the artemis lib directory.
# Exclude log4j-to-slf4j to avoid conflicts with logback
COPY logback-classic-1.2.11.jar /var/lib/artemis-instance/lib/
COPY logback-core-1.2.11.jar /var/lib/artemis-instance/lib/
COPY logstash-gelf-1.15.1.jar /var/lib/artemis-instance/lib/

# Switch to artemis user
USER artemis

EXPOSE 8161 61616 5672 1883