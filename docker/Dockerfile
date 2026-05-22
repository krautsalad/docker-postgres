FROM postgres:18.4-alpine

USER root

RUN apk add --no-cache bash dcron supervisor tini && \
    rm -rf /root/.cache /tmp/* /var/cache/apk/* /var/tmp/* && \
    mv /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint-postgres.sh && \
    mkdir -p /etc/postgresql/conf.d && \
    printf "\ninclude_dir = '/etc/postgresql/conf.d'\n" >> /usr/local/share/postgresql/postgresql.conf.sample

COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY docker/postgresql.conf /usr/local/share/postgresql/postgresql.conf.template
COPY docker/supervisord.conf /etc/supervisord.conf

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
