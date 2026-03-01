# PLANS

Plans are first-class, versioned artifacts.
They let agents work on complex changes without relying on external context.

Last updated: 2026-02-24

## When to write a plan

- Small change (under 30 minutes): write a lightweight plan in the PR description.
- Medium change (30 to 120 minutes): create a short plan and keep it in the PR body, then discard after merge.
- Large change (multi-hour, multi-file, risk): write an execution plan in docs/exec-plans/active/.

## Where plans live

- Active: docs/exec-plans/active/
- Completed: docs/exec-plans/completed/
- Tech debt: docs/exec-plans/tech-debt-tracker.md

Naming convention:
YYYY-MM-DD--short-slug.md

Example:
docs/exec-plans/active/2026-02-24--whatsapp-template-rate-limit.md

## Execution plan requirements

An execution plan must include:
- Goal and non-goals
- Context and constraints
- Proposed approach with milestones
- Test plan
- Rollout and rollback plan (if applicable)
- Progress log (append-only)
- Decision log (append-only)

If you are an agent, update the progress log as you work.

## Template

Copy docs/exec-plans/template.md or run:
scripts/harness/new-exec-plan.sh slug "Human readable title"

## Completing a plan

When work is merged:
1) move the plan file to docs/exec-plans/completed/
2) add any follow-ups to tech-debt-tracker.md
3) update QUALITY_SCORE.md if the work changes a grade