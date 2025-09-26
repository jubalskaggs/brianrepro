This drops the logback dependencies into the artemis container, as well as logback.xml.

It will maintain writing to stdout and stderr due to the use of the ConsoleAppender definition in logback.xml, but also
write to graylog using gelf.

logback.xml is expecting environment variables to be set (these are the defaults)
GRAYLOG_HOST=graylog
GRAYLOG_PORT=12201

Future improvements:
    - dont use these static jars, get the current ones, etc.
    - add additonal files to slipstream in such as (some may be better as docker secrets, etc):
        broker.xml (this one especially, since it contains <systemUsage><memoryUsage limit="1 gb"/></systemUsage> amongst other things we may want to tune.
        bootstrap.xml
        artemis-users.properties
        artemis-roles.properties
        login.config