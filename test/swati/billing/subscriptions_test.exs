defmodule Swati.Billing.SubscriptionsTest do
  use Swati.DataCase, async: true

  alias Swati.AccountsFixtures
  alias Swati.Billing
  alias Swati.Billing.{Plan, PlanProvider, ProviderSubscription, TenantSubscription}
  alias Swati.Repo
  alias Swati.Tenancy.Tenants
  alias Swati.Test.RazorpayClientStub

  @day_seconds 86_400

  setup do
    previous = Application.get_env(:swati, :razorpay_client)
    Application.put_env(:swati, :razorpay_client, RazorpayClientStub)

    on_exit(fn ->
      RazorpayClientStub.clear()
      Application.put_env(:swati, :razorpay_client, previous)
    end)

    :ok
  end

  test "schedules plan change at cycle end and keeps tenant plan" do
    scope = AccountsFixtures.user_scope_fixture()
    tenant = scope.tenant

    current_plan = create_plan("starter", "Starter", "plan_current", 49_900)
    next_plan = create_plan("smart", "Smart", "plan_next", 149_900)

    {:ok, _tenant} = Tenants.update_billing_plan(tenant, current_plan.code)

    subscription =
      insert_tenant_subscription(tenant, current_plan.code, %{
        payment_method: "card"
      })

    _ = insert_provider_subscription(subscription, current_plan, tenant)

    now = DateTime.utc_now()

    RazorpayClientStub.stub(fn opts ->
      assert opts[:method] == :patch
      assert opts[:url] =~ "/subscriptions/#{subscription.provider_subscription_id}"
      assert get_in(opts, [:json, :schedule_change_at]) == "cycle_end"

      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "plan_id" => provider_plan_id(next_plan),
           "status" => "active",
           "current_start" => DateTime.to_unix(now),
           "current_end" => DateTime.to_unix(DateTime.add(now, 30 * @day_seconds, :second)),
           "charge_at" => DateTime.to_unix(DateTime.add(now, 30 * @day_seconds, :second))
         }
       }}
    end)

    assert {:ok, _body} = Billing.change_plan(tenant, next_plan.code, :cycle_end)

    updated_subscription = Billing.subscription_for_tenant(tenant.id)
    assert updated_subscription.pending_plan_code == next_plan.code

    tenant = Tenants.get_tenant!(tenant.id)
    assert tenant.plan == current_plan.code
  end

  test "pay again creates an upcoming subscription with payment link" do
    scope = AccountsFixtures.user_scope_fixture()
    tenant = scope.tenant

    current_plan = create_plan("starter", "Starter", "plan_current", 49_900)
    next_plan = create_plan("smart", "Smart", "plan_next", 149_900)

    {:ok, _tenant} = Tenants.update_billing_plan(tenant, current_plan.code)

    subscription =
      insert_tenant_subscription(tenant, current_plan.code, %{
        payment_method: "card",
        current_end_at: DateTime.add(DateTime.utc_now(), 20 * @day_seconds, :second)
      })

    start_at = DateTime.to_unix(subscription.current_end_at)

    RazorpayClientStub.stub(fn opts ->
      assert opts[:method] == :post
      assert opts[:url] =~ "/subscriptions"
      assert get_in(opts, [:json, :start_at]) == start_at

      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "id" => "sub_new",
           "plan_id" => provider_plan_id(next_plan),
           "status" => "created",
           "quantity" => 1,
           "start_at" => start_at,
           "current_end" => start_at + 2_592_000,
           "charge_at" => start_at + 2_592_000,
           "short_url" => "https://rzp.io/i/sub_new"
         }
       }}
    end)

    assert {:ok, %{short_url: "https://rzp.io/i/sub_new"}} =
             Billing.pay_again(tenant, next_plan.code)

    upcoming = Billing.upcoming_subscription_for_tenant(tenant.id)
    assert upcoming.provider_subscription_id == "sub_new"
    assert upcoming.short_url == "https://rzp.io/i/sub_new"
    assert upcoming.metadata["created_via"] == "pay_again"
  end

  test "UPI subscriptions block plan changes and pay again before cycle end" do
    scope = AccountsFixtures.user_scope_fixture()
    tenant = scope.tenant

    current_plan = create_plan("starter", "Starter", "plan_current", 49_900)
    next_plan = create_plan("smart", "Smart", "plan_next", 149_900)

    {:ok, _tenant} = Tenants.update_billing_plan(tenant, current_plan.code)

    insert_tenant_subscription(tenant, current_plan.code, %{
      payment_method: "upi",
      current_end_at: DateTime.add(DateTime.utc_now(), 10 * @day_seconds, :second)
    })

    assert {:error, %Swati.Billing.Error{code: :upi_restriction}} =
             Billing.change_plan(tenant, next_plan.code, :now)

    assert {:error, %Swati.Billing.Error{code: :upi_restriction}} =
             Billing.pay_again(tenant, next_plan.code)
  end

  defp create_plan(code, name, provider_plan_id, amount) do
    plan =
      Repo.get_by(Plan, code: code) ||
        %Plan{}
        |> Plan.changeset(%{
          code: code,
          name: name,
          amount: amount,
          currency: "INR",
          entitlements: %{},
          status: "active"
        })
        |> Repo.insert!()

    Repo.get_by(PlanProvider, plan_id: plan.id, provider: "razorpay") ||
      %PlanProvider{}
      |> PlanProvider.changeset(%{
        plan_id: plan.id,
        provider: "razorpay",
        provider_plan_id: provider_plan_id
      })
      |> Repo.insert!()

    plan
  end

  defp provider_plan_id(plan) do
    Repo.get_by!(PlanProvider, plan_id: plan.id, provider: "razorpay").provider_plan_id
  end

  defp insert_tenant_subscription(tenant, plan_code, overrides) do
    now = DateTime.utc_now()

    attrs =
      %{
        tenant_id: tenant.id,
        provider: "razorpay",
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        plan_code: plan_code,
        status: "active",
        quantity: 1,
        current_start_at: DateTime.add(now, -1 * @day_seconds, :second),
        current_end_at: DateTime.add(now, 29 * @day_seconds, :second)
      }
      |> Map.merge(overrides)

    %TenantSubscription{}
    |> TenantSubscription.changeset(attrs)
    |> Repo.insert!()
  end

  defp insert_provider_subscription(subscription, plan, tenant) do
    %ProviderSubscription{}
    |> ProviderSubscription.changeset(%{
      provider: "razorpay",
      provider_subscription_id: subscription.provider_subscription_id,
      provider_customer_id: "cust_#{tenant.id}",
      provider_plan_id: provider_plan_id(plan),
      provider_status: "active",
      quantity: subscription.quantity
    })
    |> Repo.insert!()
  end
end
