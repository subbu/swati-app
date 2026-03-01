# Tech debt tracker

This file tracks known technical debt that impacts agent throughput, reliability, or security.

Last updated: 2026-02-24

## How to use

- Add an entry when you discover recurring friction or risk.
- If a debt item is addressed by an execution plan, link it.
- Prefer small, targeted refactor PRs over large rewrites.

## Debt list

| Area | Severity | Symptom | Suggested fix | Plan link |
| --- | --- | --- | --- | --- |
| Docs freshness | medium | docs drift after refactors | scheduled doc gardening runs | |
| Boundary enforcement | medium | occasional cross-context coupling | add structural tests for allowed edges | |
| CI and harness | low | checks not standardized in CI | wire scripts/harness/check.sh in CI | |