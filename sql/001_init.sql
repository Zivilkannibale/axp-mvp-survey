CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS submission (
  submission_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT NOW(),
  instrument_id text NOT NULL,
  instrument_version text NOT NULL,
  language text NOT NULL,
  consent_version text NOT NULL,
  definition_hash text NOT NULL
);

CREATE TABLE IF NOT EXISTS response_numeric (
  id bigserial PRIMARY KEY,
  submission_id uuid NOT NULL REFERENCES submission(submission_id),
  item_id text NOT NULL,
  value numeric,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS response_text (
  id bigserial PRIMARY KEY,
  submission_id uuid NOT NULL REFERENCES submission(submission_id),
  field_id text NOT NULL,
  text text,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS score (
  id bigserial PRIMARY KEY,
  submission_id uuid NOT NULL REFERENCES submission(submission_id),
  scale_id text NOT NULL,
  score_value numeric,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS aggregate_norms (
  instrument_version text NOT NULL,
  scale_id text NOT NULL,
  n int NOT NULL,
  mean numeric,
  sd numeric,
  p05 numeric,
  p50 numeric,
  p95 numeric,
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY (instrument_version, scale_id)
);
