#!/bin/bash
set -eo pipefail
shopt -s nullglob

mkdir -p /var/log/cron /var/log/postgresql
chown postgres:postgres /var/log/postgresql
ln -sf /proc/$$/fd/1 /var/log/cron/cron.log

# set timezone
export TZ="${TZ:-UTC}"
ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime

# set include_dir in existing installations
PGDATA="${PGDATA:-/var/lib/postgresql/18/data}"
POSTGRESQL_CONF="${PGDATA}/postgresql.conf"
if [ -f "$POSTGRESQL_CONF" ] && ! grep -qE "^[[:space:]]*include_dir[[:space:]]*=[[:space:]]*['\"]?/etc/postgresql/conf\.d" "$POSTGRESQL_CONF"; then
    echo "include_dir = '/etc/postgresql/conf.d'" >> "$POSTGRESQL_CONF"
fi

# setup cronjob
VACUUM_ENABLED="${VACUUM_ENABLED:-0}"
VACUUM_SCHEDULE="${VACUUM_SCHEDULE:-0 1 * * 6}"

rm -f /etc/crontabs/postgres

if [[ "$(printf '%s' "$VACUUM_ENABLED" | tr '[:upper:]' '[:lower:]')" =~ ^(1|on|true|yes)$ ]]; then
    {
        echo "${VACUUM_SCHEDULE} psql -U postgres -Atq -c \"SELECT datname FROM pg_database WHERE datallowconn AND datname <> 'template0';\" | xargs -n1 vacuumlo -U postgres -v && vacuumdb -U postgres --all --full --analyze --verbose >> /var/log/cron/cron.log 2>&1"
        echo ""
    } > /etc/crontabs/postgres
    chmod 600 /etc/crontabs/postgres
fi

# database parameters
SLOW_QUERY_LOG="${SLOW_QUERY_LOG:-0}"
LONG_QUERY_TIME="${LONG_QUERY_TIME:-3}"
max_connections=200
memory_gb=$(awk -v gb="${MEMORY_GB:-2}" 'BEGIN {
    if (gb + 0 < 2) gb = 2
    printf "%g", gb + 0
}')

if [[ "$(printf '%s' "${SLOW_QUERY_LOG}" | tr '[:upper:]' '[:lower:]')" =~ ^(1|on|true|yes)$ ]]; then
    log_min_duration_statement=$((LONG_QUERY_TIME * 1000))
else
    log_min_duration_statement=-1
fi

memory_bytes=$(awk -v gb="$memory_gb" 'BEGIN { printf "%d", gb * 1073741824 }')
effective_cache_size=$(awk -v b="$memory_bytes" 'BEGIN { printf "%dMB", b * 75 / 100 / 1024 / 1024 }')
maintenance_work_mem=$(awk -v b="$memory_bytes" 'BEGIN { printf "%dMB", b / 16 / 1024 / 1024 }')
shared_buffers=$(awk -v b="$memory_bytes" 'BEGIN { printf "%dMB", b * 25 / 100 / 1024 / 1024 }')
work_mem=$(awk -v b="$memory_bytes" -v mc="$max_connections" 'BEGIN {
    shared = b * 25 / 100
    printf "%dMB", (b - shared) / (mc * 3) / 1024 / 1024
}')

sed \
    -e "s/@EFFECTIVE_CACHE_SIZE@/${effective_cache_size}/g" \
    -e "s/@LOG_MIN_DURATION_STATEMENT@/${log_min_duration_statement}/g" \
    -e "s/@MAINTENANCE_WORK_MEM@/${maintenance_work_mem}/g" \
    -e "s/@MAX_CONNECTIONS@/${max_connections}/g" \
    -e "s/@MEMORY_GB@/${memory_gb}/g" \
    -e "s/@SHARED_BUFFERS@/${shared_buffers}/g" \
    -e "s/@TIMEZONE@/${TZ}/g" \
    -e "s/@WORK_MEM@/${work_mem}/g" \
    /usr/local/share/postgresql/postgresql.conf.template > /etc/postgresql/conf.d/zz-overrides-initial.conf

exec /sbin/tini -- /usr/bin/supervisord -c /etc/supervisord.conf
