# DESIGN

This is the agent-first engineering contract for Swati.
It exists to make the codebase predictable, legible, and mechanically checkable.

Last updated: 2026-02-24

## The point

Humans can infer intent from messy code.
Agents cannot. They pattern-match and replicate what they see.
Therefore we design for:
- predictable structure
- explicit boundaries
- fast feedback loops
- minimal hidden state

Deep architecture doc: design-docs/modular_monolith_design.md

## Repository shape conventions

- Business logic lives under lib/swati in bounded contexts.
- Web layer lives under lib/swati_web and stays thin.
- Docs are the system of record under docs/.
- Scripts that agents run live under scripts/harness/.

## Context structure

Inside lib/swati/context-name/ we prefer:
- context-name.ex: facade (public API)
- commands.ex: write paths, orchestration, Ecto.Multi
- queries.ex: read paths and filters
- attrs.ex or policy modules: normalize and validate map configs
- providers or adapters: external calls behind behaviours

Example patterns exist in:
- Swati.Sessions and Swati.Sessions.Ingestion
- Swati.Runtime (runtime gateway)

## Boundary parsing and normalization

Golden rule: never build on guessed data shapes.

At system boundaries, normalize and parse once:
- HTTP params: normalize in ingestion modules, then act on normalized data.
- Webhooks and integrations: normalize payloads before any side effects.
- Map-based configs: interpret them only inside policy modules.

Prefer:
- total functions that return {:ok, value} or {:error, reason}
- explicit error codes for programmatic handling

See: design-docs/internal_runtime_config.md

## Definition of done for code changes

A change is done when:
- Tests cover the new behavior and the regression.
- mix swati.harness.check passes.
- Docs are updated if behavior or APIs changed.
- Any new public API has a module doc and a clear boundary.

## Testing approach

- Prefer focused unit tests per module.
- For cross-context flows, add narrow integration tests at the facade boundary.
- Use idempotency keys for event ingestion and test idempotency explicitly.

## Web layer rules

Controllers and LiveViews should:
- validate and normalize params
- call context facades
- translate results into responses

Avoid:
- direct Repo calls
- cross-context orchestration in controllers
- embedding complex business logic in views

## When a rule repeats, upgrade it

If reviewers keep repeating the same feedback:
1) capture it in docs/design-docs/core-beliefs.md
2) then encode it as a harness check or structural test