defmodule SwatiWeb.BillingCompleteControllerTest do
  use SwatiWeb.ConnCase

  alias Swati.Billing.TenantSubscription
  alias Swati.Repo

  import Swati.AccountsFixtures

  test "GET /billing/complete renders subscription details", %{conn: conn} do
    user = user_fixture()
    tenant = Repo.preload(user, :tenant).tenant

    subscription =
      %TenantSubscription{}
      |> TenantSubscription.changeset(%{
        tenant_id: tenant.id,
        provider: "razorpay",
        provider_subscription_id: "sub_complete_test",
        plan_code: tenant.plan,
        status: "active"
      })
      |> Repo.insert!()

    conn =
      get(
        conn,
        ~p"/billing/complete?subscription_id=#{subscription.provider_subscription_id}&payment_id=pay_test"
      )

    html = html_response(conn, 200)
    assert html =~ "Subscription active"
    assert html =~ "sub_complete_test"
    assert html =~ "pay_test"
  end

  test "GET /billing/complete without subscription id returns 404", %{conn: conn} do
    conn = get(conn, ~p"/billing/complete")
    assert html_response(conn, 404) =~ "Missing subscription details"
  end
end
