FROM postgres:9.6

ENV POSTGRES_PASSWORD postgres

RUN mkdir -p /docker-entrypoint-initdb.d

# schema.sql needs to be in postgresql-init to work with s2i in oc
COPY ./postgresql-init/schema.sql /docker-entrypoint-initdb.d/
COPY rotate_password /usr/local/bin/
