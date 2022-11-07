# Web3Signer with PostgreSQL setup (Slashing Protection)

## Start Containers
### Copy sql migration files, run PostgreSQL, perform schema migration and start Web3Signer
`cd pg;docker compose -f ./docker-compose-pg.yml up`

## Terminating Containers
### Stop containers (from another terminal window)
`cd pg;docker compose -f ./docker-compose-pg.yml stop`

### Shutdown containers completely and deleting all db volumes (from another terminal window)
`cd pg;docker compose -f ./docker-compose-pg.yml down -v`

# Experimental - Web3Signer with PgBouncer + PostgreSQL (Hikari Disabled)
## Start Containers
### Copy sql migration files, run PostgreSQL, perform schema migration and start Web3Signer
`cd pgbouncer;docker compose -f ./docker-compose-pgbouncer.yml up`

## Terminating Containers
### Stop containers (from another terminal window)
`cd pgbouncer;docker compose -f ./docker-compose-pgbouncer.yml stop`

### Shutdown containers completely and deleting all db volumes (from another terminal window)
`cd pgbouncer;docker compose -f ./docker-compose-pgbouncer.yml down -v`