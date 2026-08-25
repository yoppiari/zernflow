#!/bin/bash
set -e

DATA_DIR="${DATA_DIR:-/data/postgres}"
PG_PASS="${DB_PASSWORD:-postgres_password_zernflow_secure}"
JWT_SECRET="${JWT_SECRET:-super-secret-jwt-token-with-at-least-32-chars-zernflow}"

# 1. Initialize PostgreSQL if not initialized
if [ ! -d "$DATA_DIR" ] || [ -z "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
  echo "[entrypoint] Initializing new PostgreSQL database in $DATA_DIR..."
  mkdir -p "$DATA_DIR"
  chown -R postgres:postgres "$DATA_DIR"
  su - postgres -c "/usr/lib/postgresql/*/bin/initdb -D $DATA_DIR"

  # Start temporary postgres for initialization
  su - postgres -c "/usr/lib/postgresql/*/bin/pg_ctl -D $DATA_DIR -o \"-c listen_addresses='127.0.0.1'\" -w start"

  # Execute initial roles and auth schema
  if [ -f /app/supabase/init-roles.sql ]; then
    echo "[entrypoint] Setting up database roles, extensions, and auth schema..."
    su - postgres -c "psql -v ON_ERROR_STOP=0 -f /app/supabase/init-roles.sql" || true
  fi

  # Run migrations if present
  if [ -f /app/supabase/migrations/ALL_MIGRATIONS.sql ]; then
    echo "[entrypoint] Running database migrations..."
    su - postgres -c "psql -v ON_ERROR_STOP=0 -f /app/supabase/migrations/ALL_MIGRATIONS.sql" || true
  fi

  # Stop temporary postgres
  su - postgres -c "/usr/lib/postgresql/*/bin/pg_ctl -D $DATA_DIR -m fast -w stop"
fi

chown -R postgres:postgres "$DATA_DIR"

# 2. Start PostgreSQL
echo "[entrypoint] Starting PostgreSQL..."
su - postgres -c "/usr/lib/postgresql/*/bin/pg_ctl -D $DATA_DIR -l /var/log/postgres.log -o \"-c listen_addresses='127.0.0.1'\" -w start"

# 3. Start GoTrue Auth
echo "[entrypoint] Starting GoTrue Auth on port 9999..."
export GOTRUE_API_HOST=127.0.0.1
export GOTRUE_API_PORT=9999
export GOTRUE_DB_DRIVER=postgres
export GOTRUE_DB_DATABASE_URL="postgres://supabase_auth_admin:${PG_PASS}@127.0.0.1:5432/postgres?sslmode=disable"
export GOTRUE_SITE_URL="${NEXT_PUBLIC_APP_URL:-https://flows.lumiku.com}"
export GOTRUE_URI_ALLOW_LIST="*"
export GOTRUE_DISABLE_SIGNUP="${GOTRUE_DISABLE_SIGNUP:-true}"
export GOTRUE_JWT_SECRET="${JWT_SECRET}"
export GOTRUE_JWT_EXP="3600"
export GOTRUE_JWT_ADMIN_ROLES="service_role"
export GOTRUE_JWT_AUD="authenticated"
export GOTRUE_JWT_DEFAULT_GROUP_NAME="authenticated"
export GOTRUE_EXTERNAL_EMAIL_ENABLED="true"
export GOTRUE_MAILER_AUTOCONFIRM="true"

gotrue > /var/log/gotrue.log 2>&1 &

# 4. Start PostgREST
echo "[entrypoint] Starting PostgREST on port 3001..."
export PGRST_DB_URI="postgres://authenticator:${PG_PASS}@127.0.0.1:5432/postgres"
export PGRST_DB_SCHEMAS="public,storage,graphql_public"
export PGRST_DB_ANON_ROLE="anon"
export PGRST_JWT_SECRET="${JWT_SECRET}"
export PGRST_SERVER_HOST="127.0.0.1"
export PGRST_SERVER_PORT="3001"
export PGRST_DB_USE_LEGACY_GUCS="false"

postgrest > /var/log/postgrest.log 2>&1 &

# Wait for services to be ready
sleep 3

# Check if gotrue and postgrest are running
echo "[entrypoint] Verifying internal services..."
curl -s http://127.0.0.1:9999/health || (echo "GoTrue log:" && cat /var/log/gotrue.log)
curl -s http://127.0.0.1:3001/ || (echo "PostgREST log:" && cat /var/log/postgrest.log)

# 5. Provision Default Admin User if specified
ADMIN_EMAIL="${ADMIN_EMAIL:-yoppi.ari@gmail.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-ZernflowAdmin2026!}"
ADMIN_NAME="${ADMIN_NAME:-Yoppi Ari}"

if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
  echo "[entrypoint] Provisioning admin user $ADMIN_EMAIL..."
  curl -s -X POST "http://127.0.0.1:9999/admin/users" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6MjAwMDAwMDAwMH0.xdTcldRhvmKPkJMXRTBy4xmKr3XCRpjgRuMjDpjU0fg}" \
    -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6MjAwMDAwMDAwMH0.xdTcldRhvmKPkJMXRTBy4xmKr3XCRpjgRuMjDpjU0fg}" \
    -H "Content-Type: application/json" \
    -d "{
      \"email\": \"$ADMIN_EMAIL\",
      \"password\": \"$ADMIN_PASSWORD\",
      \"email_confirm\": true,
      \"user_metadata\": {
        \"full_name\": \"$ADMIN_NAME\",
        \"name\": \"$ADMIN_NAME\"
      }
    }" || echo "[entrypoint] Admin user may already exist."
fi

# 6. Start Next.js App
echo "[entrypoint] Starting Next.js App on port 3000..."
export INTERNAL_AUTH_URL="http://127.0.0.1:9999"
export INTERNAL_REST_URL="http://127.0.0.1:3001"
export PORT=3000
export HOSTNAME="0.0.0.0"

exec node server.js
