defmodule Swati.Billing.UsageTest do
  use Swati.DataCase, async: true

  alias Swati.AccountsFixtures
  alias Swati.Agents.Agent
  alias Swati.Billing.{Entitlements, TenantSubscription, Usage, UsageCounter}
  alias Swati.Calls.Call
  alias Swati.Repo

  @day_seconds 86_400

  test "records call minutes into usage counters" do
    scope = AccountsFixtures.user_scope_fixture()
    tenant = scope.tenant

    now = DateTime.utc_now()
    end_at = DateTime.add(now, 30 * @day_seconds, :second)

    subscription =
      %TenantSubscription{}
      |> TenantSubscription.changeset(%{
        tenant_id: tenant.id,
        provider: "razorpay",
        provider_subscription_id: "sub_usage_1",
        status: "active",
        plan_code: tenant.plan,
        current_start_at: now,
        current_end_at: end_at
      })
      |> Repo.insert!()

    entitlements = Entitlements.effective(tenant)
    {:ok, _cycle} = Usage.ensure_cycle(subscription, now, end_at, entitlements)

    agent =
      %Agent{}
      |> Agent.changeset(%{
        tenant_id: tenant.id,
        name: "Test Agent",
        status: "active",
        language: "en-IN",
        voice_provider: "google",
        voice_name: "Fenrir",
        llm_provider: "google",
        llm_model: Agent.default_llm_model(),
        instructions: Agent.default_instructions(),
        tool_policy: Agent.default_tool_policy()
      })
      |> Repo.insert!()

    call =
      %Call{}
      |> Call.changeset(%{
        tenant_id: tenant.id,
        agent_id: agent.id,
        provider: :plivo,
        provider_call_id: "call_123",
        from_number: "+14155550123",
        to_number: "+14155550124",
        status: :ended,
        started_at: DateTime.utc_now(),
        ended_at: DateTime.utc_now(),
        duration_seconds: 125
      })
      |> Repo.insert!()

    assert :ok = Swati.Billing.record_call_minutes(call)

    counter =
      Repo.get_by(UsageCounter,
        tenant_id: tenant.id,
        metric: "call_minutes_used"
      )

    assert counter
    assert counter.amount == 3
  end
end
