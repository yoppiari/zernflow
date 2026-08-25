ALTER USER postgres PASSWORD 'postgres_password_zernflow_secure';

DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE ROLE supabase_admin LOGIN SUPERUSER PASSWORD 'postgres_password_zernflow_secure';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    CREATE ROLE supabase_auth_admin LOGIN SUPERUSER PASSWORD 'postgres_password_zernflow_secure';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator LOGIN NOINHERIT PASSWORD 'postgres_password_zernflow_secure';
  END IF;
END $$;

GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;

ALTER ROLE supabase_auth_admin SET search_path = auth, public;
ALTER ROLE authenticator SET search_path = public, auth, storage, graphql_public;
ALTER ROLE postgres SET search_path = public, auth, storage, graphql_public;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS auth;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role, supabase_auth_admin;

CREATE TABLE IF NOT EXISTS auth.users (
  instance_id uuid,
  id uuid primary key default gen_random_uuid(),
  aud varchar(255) default 'authenticated',
  role varchar(255) default 'authenticated',
  email varchar(255) unique,
  encrypted_password varchar(255),
  email_confirmed_at timestamptz default now(),
  invited_at timestamptz,
  confirmation_token varchar(255),
  confirmation_sent_at timestamptz,
  recovery_token varchar(255),
  recovery_sent_at timestamptz,
  email_change_token_new varchar(255),
  email_change varchar(255),
  email_change_sent_at timestamptz,
  last_sign_in_at timestamptz,
  raw_app_meta_data jsonb default '{"provider":"email","providers":["email"]}'::jsonb,
  raw_user_meta_data jsonb default '{}'::jsonb,
  is_super_admin boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  phone text default null,
  phone_confirmed_at timestamptz,
  phone_change text default '',
  phone_change_token varchar(255) default '',
  phone_change_sent_at timestamptz,
  confirmed_at timestamptz default now(),
  email_change_token_current varchar(255) default '',
  email_change_confirm_status smallint default 0,
  banned_until timestamptz,
  reauthentication_token varchar(255) default '',
  reauthentication_sent_at timestamptz,
  is_sso_user boolean default false not null,
  deleted_at timestamptz,
  is_anonymous boolean default false not null
);

CREATE TABLE IF NOT EXISTS auth.refresh_tokens (
  instance_id uuid,
  id bigserial primary key,
  token varchar(255),
  user_id varchar(255),
  revoked boolean,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  parent varchar(255),
  session_id uuid
);

CREATE TABLE IF NOT EXISTS auth.instances (
  id uuid primary key,
  uuid uuid,
  raw_base_config text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

CREATE TABLE IF NOT EXISTS auth.audit_log_entries (
  instance_id uuid,
  id uuid primary key default gen_random_uuid(),
  payload json,
  created_at timestamptz default now(),
  ip_address varchar(64) default ''
);

CREATE TABLE IF NOT EXISTS auth.identities (
  provider_id text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  identity_data jsonb NOT NULL,
  provider text NOT NULL,
  last_sign_in_at timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  email text,
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  CONSTRAINT identities_pkey PRIMARY KEY (id),
  CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider)
);

CREATE TABLE IF NOT EXISTS auth.sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  factor_id uuid,
  aal varchar(255),
  not_after timestamp with time zone,
  refreshed_at timestamp with time zone,
  user_agent text,
  ip inet,
  tag text,
  CONSTRAINT sessions_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS auth.flow_state (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  auth_code text NOT NULL,
  code_challenge_method text NOT NULL,
  code_challenge text NOT NULL,
  provider_type text NOT NULL,
  provider_access_token text,
  provider_refresh_token text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  authentication_method text NOT NULL,
  auth_code_issued_at timestamp with time zone,
  CONSTRAINT flow_state_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS auth.mfa_factors (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  friendly_name text,
  factor_type text NOT NULL,
  status text NOT NULL,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  secret text,
  phone text,
  last_challenged_at timestamp with time zone,
  CONSTRAINT mfa_factors_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS auth.mfa_challenges (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  factor_id uuid NOT NULL REFERENCES auth.mfa_factors(id) ON DELETE CASCADE,
  created_at timestamp with time zone default now(),
  verified_at timestamp with time zone,
  ip_address inet NOT NULL,
  otp_code text,
  web_authn_session_data jsonb,
  CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS auth.mfa_amr_claims (
  session_id uuid NOT NULL REFERENCES auth.sessions(id) ON DELETE CASCADE,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  authentication_method text NOT NULL,
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  CONSTRAINT mfa_amr_claims_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS auth.sso_providers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_id text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  CONSTRAINT sso_providers_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS auth.sso_domains (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  sso_provider_id uuid NOT NULL REFERENCES auth.sso_providers(id) ON DELETE CASCADE,
  domain text NOT NULL,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  CONSTRAINT sso_domains_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS auth.saml_providers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  sso_provider_id uuid NOT NULL REFERENCES auth.sso_providers(id) ON DELETE CASCADE,
  entity_id text NOT NULL UNIQUE,
  metadata_xml text NOT NULL,
  metadata_url text,
  attribute_mapping jsonb,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  name_id_format text,
  CONSTRAINT saml_providers_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS auth.saml_relay_states (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  sso_provider_id uuid NOT NULL REFERENCES auth.sso_providers(id) ON DELETE CASCADE,
  request_id text NOT NULL,
  for_email text,
  redirect_to text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  flow_state_id uuid REFERENCES auth.flow_state(id) ON DELETE CASCADE,
  CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS auth.schema_migrations (
  version varchar(255) primary key
);

GRANT ALL ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin, postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin, postgres;
GRANT ALL ON ALL ROUTINES IN SCHEMA auth TO supabase_auth_admin, postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA auth TO service_role;
GRANT SELECT ON auth.users TO authenticated, anon;

CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION auth.role() RETURNS text AS $$
  SELECT nullif(current_setting('request.jwt.claim.role', true), '')::text;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION auth.email() RETURNS text AS $$
  SELECT nullif(current_setting('request.jwt.claim.email', true), '')::text;
$$ LANGUAGE sql STABLE;
