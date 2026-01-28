defmodule SwatiWeb.BillingLive.IndexTest do
  use SwatiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swati.AccountsFixtures

  alias Swati.Billing.{Plan, PlanProvider, TenantSubscription}
  alias Swati.Repo
  alias Swati.Tenancy.Tenants
  alias Swati.Test.RazorpayClientStub

  @day_seconds 86_400

  setup do
    previous_client = Application.get_env(:swati, :razorpay_client)
    previous_stub = Application.get_env(:swati, :razorpay_stub)

    Application.put_env(:swati, :razorpay_client, RazorpayClientStub)

    Application.put_env(:swati, :razorpay_stub, fn opts ->
      if opts[:method] == :get and opts[:url] == "https://api.razorpay.com/v1/invoices" do
        {:ok, %Req.Response{status: 200, body: %{"items" => []}}}
      else
        {:error, :missing_stub}
      end
    end)

    on_exit(fn ->
      Application.put_env(:swati, :razorpay_client, previous_client)
      Application.put_env(:swati, :razorpay_stub, previous_stub)
    end)

    :ok
  end

  test "hides pay again for card subscriptions", %{conn: conn} do
    user = user_fixture()
    tenant = Repo.preload(user, :tenant).tenant

    plan = create_plan("starter", "Starter", "plan_card", 49_900)
    {:ok, _tenant} = Tenants.update_billing_plan(tenant, plan.code)

    insert_subscription(tenant, plan.code, "active", %{
      payment_method: "card"
    })

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/settings/billing")

    refute has_element?(view, "#billing-pay-again")
  end

  test "shows pay again for UPI halted subscriptions", %{conn: conn} do
    user = user_fixture()
    tenant = Repo.preload(user, :tenant).tenant

    plan = create_plan("starter", "Starter", "plan_upi", 49_900)
    {:ok, _tenant} = Tenants.update_billing_plan(tenant, plan.code)

    insert_subscription(tenant, plan.code, "halted", %{
      payment_method: "upi",
      current_end_at: DateTime.add(DateTime.utc_now(), -1 * @day_seconds, :second)
    })

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/settings/billing")

    assert has_element?(view, "#billing-pay-again")
    refute has_element?(view, "#billing-pay-again[disabled]")
  end

  test "shows cancellation notice when cancellation is scheduled", %{conn: conn} do
    user = user_fixture()
    tenant = Repo.preload(user, :tenant).tenant

    plan = create_plan("starter", "Starter", "plan_cancel", 49_900)
    {:ok, _tenant} = Tenants.update_billing_plan(tenant, plan.code)

    insert_subscription(tenant, plan.code, "active", %{
      cancelled_at: DateTime.add(DateTime.utc_now(), 10 * @day_seconds, :second)
    })

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/settings/billing")

    assert has_element?(view, "#billing-cancel-notice")
    refute has_element?(view, "#billing-cancel")
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

  defp insert_subscription(tenant, plan_code, status, overrides) do
    now = DateTime.utc_now()

    attrs =
      %{
        tenant_id: tenant.id,
        provider: "razorpay",
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        plan_code: plan_code,
        status: status,
        quantity: 1,
        current_start_at: DateTime.add(now, -1 * @day_seconds, :second),
        current_end_at: DateTime.add(now, 29 * @day_seconds, :second)
      }
      |> Map.merge(overrides)

    %TenantSubscription{}
    |> TenantSubscription.changeset(attrs)
    |> Repo.insert!()
  end
end
