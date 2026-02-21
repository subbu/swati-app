# Feature Flags

Read when: adding a new flag, changing tenant rollout, or adding per-flag config.

## Overview

- Flags use `FunWithFlags` with the Ecto store.
- Tenant targeting is supported via `FunWithFlags.Actor` for `Swati.Tenancy.Tenant`.
- Tenant config for a flag is stored in `tenant.policy["feature_configs"][flag_key]`.

## Key Modules

- `/Users/subbu/Repos/subbu/swati-1/lib/swati/feature_flags.ex`
  - App-level wrappers around `FunWithFlags` calls.
- `/Users/subbu/Repos/subbu/swati-1/lib/swati/tenancy/tenant_fun_with_flags_actor.ex`
  - Tenant actor identity used for per-tenant flag checks.
- `/Users/subbu/Repos/subbu/swati-1/lib/swati/tenancy/tenants.ex`
  - `feature_config/3`, `update_feature_config/3`.

## Sessions AI Recommendations

- Flag key: `:sessions_ai_recommendations`.
- Typed config module:
  `/Users/subbu/Repos/subbu/swati-1/lib/swati/features/sessions_ai_recommendations.ex`
- Current config keys:
  - `"model"` (string)
  - `"temperature"` (0.0..1.0)
  - `"timeout_ms"` (5_000..120_000)

## IEx Ops

```elixir
alias Swati.FeatureFlags
alias Swati.Tenancy.Tenants

tenant = Tenants.get_tenant!(tenant_id)

# Toggle per tenant
FeatureFlags.enable_sessions_ai_recommendations(tenant)
FeatureFlags.disable_sessions_ai_recommendations(tenant)
FeatureFlags.sessions_ai_recommendations?(tenant)

# Update tenant config for this feature
Tenants.update_feature_config(tenant, "sessions_ai_recommendations", %{
  "model" => "gpt-5",
  "temperature" => 0.2,
  "timeout_ms" => 30_000
})

Tenants.feature_config(tenant, "sessions_ai_recommendations", %{})
```

## Add New Feature Flag

1. Add a wrapper function in `/Users/subbu/Repos/subbu/swati-1/lib/swati/feature_flags.ex`.
2. If config is needed, add typed config module under `/Users/subbu/Repos/subbu/swati-1/lib/swati/features/`.
3. Read config through `Tenants.feature_config/3`; write through `Tenants.update_feature_config/3`.
4. Gate UI and server actions with the flag check.
5. Add focused tests for flag on/off behavior.
