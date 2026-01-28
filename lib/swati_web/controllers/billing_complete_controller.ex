defmodule SwatiWeb.BillingCompleteController do
  use SwatiWeb, :controller

  alias Swati.Billing.Queries

  @provider "razorpay"

  def show(conn, params) do
    subscription_id = Map.get(params, "subscription_id")
    payment_id = Map.get(params, "payment_id")

    if is_binary(subscription_id) and subscription_id != "" do
      tenant_subscription =
        Queries.get_tenant_subscription_by_provider_id(@provider, subscription_id)

      provider_subscription =
        Queries.get_provider_subscription_by_provider_id(@provider, subscription_id)

      plan =
        case tenant_subscription do
          %{plan_code: plan_code} -> Queries.get_plan_by_code(plan_code)
          _ -> nil
        end

      render(conn, :show,
        subscription_id: subscription_id,
        payment_id: payment_id,
        tenant_subscription: tenant_subscription,
        provider_subscription: provider_subscription,
        plan: plan,
        invalid_link?: false
      )
    else
      conn
      |> put_status(:not_found)
      |> render(:show,
        subscription_id: nil,
        payment_id: payment_id,
        tenant_subscription: nil,
        provider_subscription: nil,
        plan: nil,
        invalid_link?: true
      )
    end
  end
end
