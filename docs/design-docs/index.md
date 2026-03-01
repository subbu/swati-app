# Design docs index

This directory contains design history and system contracts.
Design docs should be discoverable, short, and linked from here.

Last updated: 2026-02-24

## Core docs

- [core-beliefs](core-beliefs.md) - agent-first operating principles and golden rules
- [harness engineering](harness_engineering.md) - how this repo implements an agent-first harness
- [modular monolith design](modular_monolith_design.md) - DDD-lite modular monolith pattern and context map
- [internal runtime config](internal_runtime_config.md) - internal runtime contract and session ingestion
- [channel adapters](channel_adapters.md) - channel provider adapters and invariants
- [razorpay subscriptions HLD](razorpay_subscriptions_hld.md) - billing high-level design

## Adding a new design doc

1) Create a new file in this directory.
2) Use the template below.
3) Link it from this index in the same PR.

### Template

# Title

Status: draft | accepted | superseded
Last updated: YYYY-MM-DD
Owners: team-or-handle

## Context

## Decision

## Consequences

## Verification

How do we know this stays true
- tests
- linters
- runbooks
- monitoring