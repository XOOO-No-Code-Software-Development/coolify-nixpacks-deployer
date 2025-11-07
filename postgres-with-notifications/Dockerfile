FROM postgres:16-alpine

LABEL maintainer="XOOO AI Platform"
LABEL description="PostgreSQL 16 with schema change notifications"

# Copy initialization script
# Scripts in /docker-entrypoint-initdb.d/ are automatically executed
# when the database is first initialized
COPY init-schema-notifications.sql /docker-entrypoint-initdb.d/

# The entrypoint and command from the base postgres image are inherited
# and will automatically run any .sql files in /docker-entrypoint-initdb.d/
