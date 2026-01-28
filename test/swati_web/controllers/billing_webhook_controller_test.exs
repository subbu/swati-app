defmodule SwatiWeb.BillingWebhookControllerTest do
  use SwatiWeb.ConnCase, async: false

  alias Swati.Accounts.{User, UserToken}
  alias Swati.Billing.{BillingCustomer, BillingEvent, TenantSubscription}
  alias Swati.Repo

  @day_seconds 86_400

  test "creates tenant and user from subscription activation", %{conn: conn} do
    now = DateTime.utc_now()
    email = "new_customer@example.com"

    payload = %{
      "event" => "subscription.activated",
      "payload" => %{
        "subscription" => %{
          "entity" => %{
            "id" => "sub_123",
            "plan_id" => "plan_S7yIQ3Y3D5NXUf",
            "customer_email" => email,
            "customer_contact" => "+919999999999",
            "status" => "active",
            "current_start" => DateTime.to_unix(now),
            "current_end" => DateTime.to_unix(DateTime.add(now, 30 * @day_seconds, :second)),
            "quantity" => 1,
            "notes" => %{
              "plan_id" => "starter",
              "plan_name" => "Starter",
              "source" => "swatiweb"
            }
          }
        }
      }
    }

    raw_body = Jason.encode!(payload)

    signature =
      :crypto.mac(:hmac, :sha256, "test_razorpay_webhook", raw_body)
      |> Base.encode16(case: :lower)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-razorpay-signature", signature)
      |> post("/api/v1/billing/razorpay/webhook", raw_body)

    assert response(conn, 200) == "ok"

    user = Repo.get_by(User, email: email)
    assert user

    user = Repo.preload(user, :tenant)
    tenant = user.tenant
    assert tenant
    assert tenant.status == "active"
    assert tenant.plan == "starter"

    subscription = Repo.get_by(TenantSubscription, provider_subscription_id: "sub_123")
    assert subscription
    assert subscription.status == "active"
    assert subscription.tenant_id == tenant.id

    customer = Repo.get_by(BillingCustomer, tenant_id: tenant.id, provider: "razorpay")
    assert customer
    assert customer.email == email

    token = Repo.get_by(UserToken, user_id: user.id, context: "login")
    assert token

    event = Repo.get_by(BillingEvent, event_type: "subscription.activated")
    assert event
    assert event.processed_at
  end

  test "skips payment captured without subscription id", %{conn: conn} do
    payload = %{
      "event" => "payment.captured",
      "payload" => %{
        "payment" => %{
          "entity" => %{
            "id" => "pay_123",
            "status" => "captured",
            "email" => "skipped@example.com",
            "notes" => %{"source" => "swatiweb"}
          }
        }
      }
    }

    raw_body = Jason.encode!(payload)

    signature =
      :crypto.mac(:hmac, :sha256, "test_razorpay_webhook", raw_body)
      |> Base.encode16(case: :lower)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-razorpay-signature", signature)
      |> post("/api/v1/billing/razorpay/webhook", raw_body)

    assert response(conn, 200) == "ok"

    event = Repo.get_by(BillingEvent, event_type: "payment.captured")
    assert event
    assert event.processed_at
    assert is_nil(event.processing_error)

    refute Repo.get_by(User, email: "skipped@example.com")
  end

  test "rejects invalid Razorpay signature", %{conn: conn} do
    payload = %{"event" => "subscription.activated"}
    raw_body = Jason.encode!(payload)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-razorpay-signature", "bad")
      |> post("/api/v1/billing/razorpay/webhook", raw_body)

    assert response(conn, 401) == "invalid signature"
  end
end
