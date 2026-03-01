# AGENTS

Short map for coding agents. Not a manual.
Goal: maximize legibility, predictable navigation, cheap feedback loops.

Harness principles (from OpenAI harness engineering):
- AGENTS.md = table of contents, not full rulebook
- progressive disclosure: map first, details by links
- repo-local docs = system of record
- encode repeated rules as mechanical checks

## Start here (in order)
1. ARCHITECTURE.md
2. docs/README.md
3. docs/DESIGN.md
4. docs/design-docs/index.md
5. docs/references/repo-map.md

## Default loop
1. Read only the docs needed for the task.
2. Make the smallest correct change.
3. Run checks:
   - `mix swati.harness.check`
   - `mix swati.docs.lint`
   - `mix precommit` before handoff
4. Fix all failures.
5. If behavior/API changed, update docs in same change.

## Non-negotiables
- Keep this file short (`<120` lines). Move detail to `docs/`.
- Prefer many small modules/files; split before ~500 LOC.
- Use `Req` for HTTP calls. Do not add `:httpoison`, `:tesla`, `:httpc`.
- Keep web layer thin: controllers/liveviews call facades, not deep internals.
- Parse/normalize at boundaries; reject invalid shapes explicitly.
- Preserve idempotency on retryable ingestion/event paths.
- Use current LiveView APIs (`<.link navigate|patch>`, `push_navigate`, `push_patch`).
- No inline `<script>` in HEEx. Put JS/hooks in `assets/js`.
- Avoid destructive git ops (`reset --hard`, `clean`, `checkout --`). Use `trash` for deletes.
- Do not revert or rewrite unrelated local changes.

## Auth/routing quick guardrails
- Auth-required LiveViews: existing `live_session :require_authenticated_user`.
- Mixed-auth LiveViews: existing `live_session :current_user`.
- Pass `current_scope` to `Layouts.app` and context calls.
- In templates use `@current_scope.user` (not `@current_user`).

## Planning and docs
- Medium/Large work: use execution plans in `docs/exec-plans/active/` (see `docs/PLANS.md`).
- Template: `docs/exec-plans/template.md`.
- Move finished plans to `docs/exec-plans/completed/`.
- Keep docs short and linked (`docs/README.md`).

## Reference map
- Architecture: `ARCHITECTURE.md`
- Design contract: `docs/DESIGN.md`
- Core beliefs: `docs/design-docs/core-beliefs.md`
- Harness design: `docs/design-docs/harness_engineering.md`
- Runtime contract: `docs/design-docs/internal_runtime_config.md`
- Context map: `docs/design-docs/modular_monolith_design.md`
- Reliability: `docs/RELIABILITY.md`
- Security: `docs/SECURITY.md`
- Quality rubric: `docs/QUALITY_SCORE.md`
- Commands: `docs/references/dev-commands.md`
- Mix tasks: `docs/references/mix_tasks.md`
- Phoenix/Elixir detail: `docs/references/phoenix-elixir-guidelines.md`

## Escalate to human when
- product/UX intent ambiguous
- security/PII/finance policy change
- irreversible side effects
- conflicting requirements across docs

## Dev/Test credentials
email: subbu@simplyguest.com
pwd: CSwGFhvgB2KqqR3R2dk-oR7I

email: subramani.athikunte@gmail.com
pwd: CSwGFhvgB2KqqR3R2dk-oR7I

Email is configured on resend.com.
Registration email: subramani.athikunte@gmail.com.
swati.ai DNS entries are configured.
