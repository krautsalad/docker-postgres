# docker-postgres

PostgreSQL with memory tuning, optional slow-query logging, and scheduled vacuum jobs.

**docker-postgres** extends the official [PostgreSQL Docker image](https://hub.docker.com/_/postgres). At startup it generates a tuned `postgresql.conf` from environment variables, runs PostgreSQL under supervisord together with cron, and can schedule full maintenance on every database (`vacuumlo` and `vacuumdb --all --full --analyze --verbose`).

## Configuration

### Docker Compose Example

```yml
# docker-compose.yml
services:
  postgres:
    container_name: postgres
    environment:
      LONG_QUERY_TIME: 3
      MEMORY_GB: 2
      POSTGRES_DB: example
      POSTGRES_PASSWORD: VerySecurePassword
      POSTGRES_USER: postgres
      SLOW_QUERY_LOG: 1
      TZ: Europe/Berlin
      VACUUM_ENABLED: 1
      VACUUM_SCHEDULE: 0 1 * * 6
    healthcheck:
      interval: 30s
      retries: 10
      start_period: 10s
      test: ["CMD", "pg_isready", "-d", "example", "-U", "postgres"]
      timeout: 10s
    image: krautsalad/postgres
    ports:
      - "5432:5432"
    restart: unless-stopped
    volumes:
      - ./postgres-config/zz-overrides.conf:/etc/postgresql/conf.d/zz-overrides.conf:ro
      - ./postgres-logs:/var/log/postgresql
      - ./postgres-data:/var/lib/postgresql
```

### Environment Variables

#### Image-specific

| Variable | Default | Description |
| --- | --- | --- |
| `LONG_QUERY_TIME` | `3` | Queries running longer than this many seconds are logged when slow query logging is enabled. |
| `MEMORY_GB` | `2` | Memory budget for the database in gigabytes (minimum `2`). Used to calculate tuned settings (see [PostgreSQL Settings Calculator](https://database.gkanev.com/postgresql/)). |
| `SLOW_QUERY_LOG` | `0` | Enables slow query logging via `log_min_duration_statement`. |
| `TZ` | `UTC` | Timezone for logs and cron. |
| `VACUUM_ENABLED` | `0` | Enables the cron job which removes orphaned large objects, reclaims disk space by rewriting tables and updates planner statistics. |
| `VACUUM_SCHEDULE` | `0 1 * * 6` | Cron expression for the vacuum job (default: Saturday at 01:00). Only used when the cron job is enabled. |

#### Official

This image supports the upstream variables. Common ones:

| Variable | Default | Description |
| --- | --- | --- |
| `POSTGRES_DB` | — | Database created on first start. |
| `POSTGRES_PASSWORD` | — | Password for `POSTGRES_USER` |
| `POSTGRES_USER` | `postgres` | Superuser name (also used as default user when creating `POSTGRES_DB`). |

See the [official documentation](https://hub.docker.com/_/postgres) for the full list.

## How it works

At container start, the custom entrypoint reads the tuning variables, substitutes placeholders in `postgresql.conf.template`, and writes `/etc/postgresql/conf.d/zz-overrides-initial.conf`. You can optionally override PostgreSQL settings further by mounting a custom config to `/etc/postgresql/conf.d/zz-overrides.conf`, as in the Docker Compose example above. If `VACUUM_ENABLED` is on, it installs a cron file at `/etc/crontabs/postgres`.

Supervisord then starts PostgreSQL (via the official image entrypoint) and `crond` for scheduled jobs. Database files are stored under `/var/lib/postgresql`; mount a volume there to persist data.

## Source Code

You can find the full source code on [GitHub](https://github.com/krautsalad/docker-postgres).
