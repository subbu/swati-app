# DB schema (generated)

This file is intended to be generated from the database schema.
Do not hand-edit.

Last updated: 2026-02-24

## How to regenerate

Option A (recommended): pg_dump schema-only against a local DB:
- pg_dump --schema-only --no-owner --no-privileges "$DATABASE_URL" > docs/generated/db-schema.sql

Option B: document tables from Ecto schema modules (future improvement).

## Current state

TODO: wire a generation script and update this file from CI.