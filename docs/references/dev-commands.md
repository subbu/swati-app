# Developer commands

Common local commands for Swati development.
Adjust to your environment.

Last updated: 2026-02-24

## Harness loop

Run these often:
- mix swati.harness.check
- mix swati.docs.lint

## Phoenix

- mix phx.server
- iex -S mix phx.server

## Tests

- mix test
- mix test test/swati/sessions
- mix test --failed

## Formatting

- mix format
- mix format --check-formatted

## Database

Typical Ecto commands (requires DATABASE_URL or config):
- mix ecto.create
- mix ecto.migrate
- mix ecto.rollback

## Ops tasks

See: mix_tasks.md