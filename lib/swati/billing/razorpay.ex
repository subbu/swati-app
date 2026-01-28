defmodule Swati.Billing.Razorpay do
  require Logger

  alias Swati.Billing.Razorpay.ClientReq

  @base_url "https://api.razorpay.com/v1"

  def verify_signature(_raw_body, nil), do: {:error, :missing_signature}
  def verify_signature(_raw_body, ""), do: {:error, :missing_signature}

  def verify_signature(raw_body, signature) when is_binary(raw_body) and is_binary(signature) do
    secret = fetch_webhook_secret!()
    expected = :crypto.mac(:hmac, :sha256, secret, raw_body) |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(expected, signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  def event_type(params) when is_map(params) do
    Map.get(params, "event")
  end

  def provider_event_id(params, raw_body) when is_map(params) and is_binary(raw_body) do
    Map.get(params, "id") ||
      Map.get(params, "event_id") ||
      hash_payload(raw_body)
  end

  def subscription_entity(params) when is_map(params) do
    get_in(params, ["payload", "subscription", "entity"]) ||
      get_in(params, ["payload", "subscription", "entity", "subscription"]) ||
      %{}
  end

  def payment_entity(params) when is_map(params) do
    get_in(params, ["payload", "payment", "entity"]) || %{}
  end

  def subscription_id(params) when is_map(params) do
    subscription_entity(params)["id"] ||
      payment_entity(params)["subscription_id"]
  end

  def notes(params) when is_map(params) do
    subscription_entity(params)["notes"] ||
      payment_entity(params)["notes"] ||
      %{}
  end

  def plan_id(params) when is_map(params) do
    subscription_entity(params)["plan_id"] || payment_entity(params)["plan_id"]
  end

  def customer_email(params) when is_map(params) do
    subscription_entity(params)["customer_email"] || payment_entity(params)["email"]
  end

  def customer_contact(params) when is_map(params) do
    subscription_entity(params)["customer_contact"] || payment_entity(params)["contact"]
  end

  def customer_id(params) when is_map(params) do
    subscription_entity(params)["customer_id"] || payment_entity(params)["customer_id"]
  end

  def timestamp_to_datetime(nil), do: nil

  def timestamp_to_datetime(value) when is_integer(value) do
    case DateTime.from_unix(value) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  def map_status(nil), do: "pending"

  def map_status(status) when is_binary(status) do
    case status do
      "active" -> "active"
      "authenticated" -> "pending"
      "created" -> "pending"
      "pending" -> "pending"
      "halted" -> "halted"
      "paused" -> "paused"
      "cancelled" -> "cancelled"
      "completed" -> "completed"
      "expired" -> "expired"
      _ -> "pending"
    end
  end

  def fetch_subscription(subscription_id) when is_binary(subscription_id) do
    {key_id, key_secret} = fetch_api_keys!()

    client().request(
      method: :get,
      url: "#{@base_url}/subscriptions/#{subscription_id}",
      auth: {:basic, "#{key_id}:#{key_secret}"}
    )
  end

  def update_subscription(subscription_id, attrs)
      when is_binary(subscription_id) and is_map(attrs) do
    {key_id, key_secret} = fetch_api_keys!()

    client().request(
      method: :patch,
      url: "#{@base_url}/subscriptions/#{subscription_id}",
      auth: {:basic, "#{key_id}:#{key_secret}"},
      json: attrs
    )
  end

  def cancel_subscription(subscription_id, cancel_at_cycle_end \\ true)
      when is_binary(subscription_id) do
    {key_id, key_secret} = fetch_api_keys!()

    payload =
      if cancel_at_cycle_end do
        %{cancel_at_cycle_end: 1}
      else
        %{}
      end

    client().request(
      method: :post,
      url: "#{@base_url}/subscriptions/#{subscription_id}/cancel",
      auth: {:basic, "#{key_id}:#{key_secret}"},
      json: payload
    )
  end

  def cancel_scheduled_changes(subscription_id) when is_binary(subscription_id) do
    {key_id, key_secret} = fetch_api_keys!()

    client().request(
      method: :post,
      url: "#{@base_url}/subscriptions/#{subscription_id}/cancel_scheduled_changes",
      auth: {:basic, "#{key_id}:#{key_secret}"}
    )
  end

  def create_subscription(attrs) when is_map(attrs) do
    {key_id, key_secret} = fetch_api_keys!()

    client().request(
      method: :post,
      url: "#{@base_url}/subscriptions",
      auth: {:basic, "#{key_id}:#{key_secret}"},
      json: attrs
    )
  end

  def fetch_invoices(subscription_id, count \\ 10)
      when is_binary(subscription_id) and is_integer(count) do
    {key_id, key_secret} = fetch_api_keys!()

    client().request(
      method: :get,
      url: "#{@base_url}/invoices",
      auth: {:basic, "#{key_id}:#{key_secret}"},
      params: %{subscription_id: subscription_id, count: count}
    )
  end

  defp client do
    Application.get_env(:swati, :razorpay_client, ClientReq)
  end

  defp fetch_api_keys! do
    config = Application.get_env(:swati, :razorpay, [])
    key_id = Keyword.get(config, :key_id)
    key_secret = Keyword.get(config, :key_secret)

    if is_binary(key_id) and is_binary(key_secret) do
      {key_id, key_secret}
    else
      Logger.error("razorpay api keys missing")
      raise "RAZORPAY_KEY_ID/RAZORPAY_KEY_SECRET missing"
    end
  end

  defp fetch_webhook_secret! do
    config = Application.get_env(:swati, :razorpay, [])
    secret = Keyword.get(config, :webhook_secret)

    if is_binary(secret) do
      secret
    else
      Logger.error("razorpay webhook secret missing")
      raise "RAZORPAY_WEBHOOK_SECRET missing"
    end
  end

  defp hash_payload(raw_body) do
    :crypto.hash(:sha256, raw_body)
    |> Base.encode16(case: :lower)
  end
end
