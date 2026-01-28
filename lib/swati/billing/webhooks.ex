defmodule Swati.Billing.Webhooks do
  require Logger

  alias Swati.Accounts
  alias Swati.Accounts.User

  alias Swati.Billing.{
    BillingCustomer,
    BillingEvent,
    Config,
    Entitlements,
    Grace,
    Management,
    Notifications,
    Plans,
    Queries,
    Razorpay,
    TenantSubscription,
    Usage
  }

  alias Swati.Repo
  alias Swati.Tenancy.{Tenant, Tenants}

  @provider "razorpay"

  def ingest_razorpay(params, raw_body) when is_map(params) and is_binary(raw_body) do
    event_type = Razorpay.event_type(params) || "unknown"
    provider_event_id = Razorpay.provider_event_id(params, raw_body)

    changeset =
      BillingEvent.changeset(%BillingEvent{}, %{
        provider: @provider,
        provider_event_id: provider_event_id,
        event_type: event_type,
        payload: params,
        received_at: DateTime.utc_now()
      })

    case Repo.insert(changeset,
           on_conflict: :nothing,
           conflict_target: [:provider, :provider_event_id],
           returning: [:id]
         ) do
      {:ok, %BillingEvent{id: nil}} ->
        :ok

      {:ok, %BillingEvent{} = event} ->
        %{"event_id" => event.id}
        |> Swati.Workers.ProcessSubscriptionEvent.new(queue: :billing, unique: [fields: [:args]])
        |> Oban.insert()

        :ok

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def process_event(event_id) do
    event = Queries.get_billing_event!(event_id)

    if event.processed_at do
      :ok
    else
      case apply_event(event) do
        :ok -> Management.mark_event_processed(event)
        {:error, reason} -> Management.mark_event_failed(event, reason)
      end
    end
  end

  defp apply_event(%BillingEvent{} = event) do
    params = event.payload
    event_type = event.event_type
    action = event_action(event_type)

    # Provider subscriptions store raw provider state; tenant subscriptions hold normalized state.
    if action == :ignore do
      Logger.info("razorpay event ignored type=#{event_type}")
      :ok
    else
      with {:ok, tenant, signup} <- resolve_tenant(params, action),
           existing <- existing_subscription(params),
           {:ok, customer_attrs} <- billing_customer_attrs(params, tenant),
           {:ok, provider_attrs} <- provider_subscription_attrs(params, existing),
           {:ok, tenant_attrs} <- tenant_subscription_attrs(params, tenant, existing),
           {:ok, _customer} <- Management.upsert_billing_customer(customer_attrs),
           {:ok, _provider} <- Management.upsert_provider_subscription(provider_attrs),
           {:ok, subscription} <- Management.upsert_tenant_subscription(tenant_attrs) do
        plan_code = Map.get(tenant_attrs, :plan_code)
        _ = maybe_update_plan(tenant, plan_code)
        :ok = apply_action(action, tenant, subscription, params)
        _ = maybe_send_magic_link(signup)
        :ok
      else
        {:skip, reason} ->
          Logger.info("razorpay event skipped type=#{event_type} reason=#{reason}")
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp resolve_tenant(params, action) do
    subscription_id = Razorpay.subscription_id(params)
    customer_id = Razorpay.customer_id(params)

    cond do
      is_binary(subscription_id) ->
        case Queries.get_tenant_subscription_by_provider_id(@provider, subscription_id) do
          %TenantSubscription{} = subscription ->
            subscription = Repo.preload(subscription, :tenant)
            {:ok, subscription.tenant, nil}

          nil ->
            resolve_tenant_by_customer(customer_id, params, action)
        end

      true ->
        resolve_tenant_by_customer(customer_id, params, action)
    end
  end

  defp resolve_tenant_by_customer(customer_id, params, action) do
    if is_binary(customer_id) do
      case Queries.get_billing_customer_by_provider_id(@provider, customer_id) do
        %BillingCustomer{} = customer ->
          customer = Repo.preload(customer, :tenant)
          {:ok, customer.tenant, nil}

        nil ->
          resolve_email_tenant(params, action)
      end
    else
      resolve_email_tenant(params, action)
    end
  end

  defp resolve_email_tenant(params, action) do
    email = Razorpay.customer_email(params)

    if is_binary(email) do
      case Accounts.get_user_by_email(email) do
        %User{} = user ->
          user = Repo.preload(user, :tenant)

          case user.tenant do
            %Tenant{} = tenant -> {:ok, tenant, nil}
            _ -> {:error, :missing_tenant}
          end

        nil ->
          maybe_create_tenant(email, params, action)
      end
    else
      {:skip, :missing_tenant}
    end
  end

  defp maybe_create_tenant(email, params, action) do
    subscription_id = Razorpay.subscription_id(params)

    if action in [:activate, :charge] and is_binary(subscription_id) do
      tenant_name = tenant_name(params, email)

      case Accounts.register_user(%{email: email, tenant_name: tenant_name}) do
        {:ok, user} ->
          user = Repo.preload(user, :tenant)

          case user.tenant do
            %Tenant{} = tenant -> {:ok, tenant, %{user: user}}
            _ -> {:error, :missing_tenant}
          end

        {:error, %Ecto.Changeset{}} ->
          case Accounts.get_user_by_email(email) do
            %User{} = user ->
              user = Repo.preload(user, :tenant)

              case user.tenant do
                %Tenant{} = tenant -> {:ok, tenant, nil}
                _ -> {:error, :missing_tenant}
              end

            nil ->
              {:error, :signup_failed}
          end
      end
    else
      {:skip, :awaiting_subscription}
    end
  end

  defp tenant_name(params, email) do
    notes = Razorpay.notes(params)
    name = Map.get(notes, "tenant_name") || Map.get(notes, "workspace_name")
    resolved = if is_binary(name) and String.trim(name) != "", do: name, else: nil
    resolved || default_tenant_name(email)
  end

  defp default_tenant_name(email) do
    base =
      email
      |> String.split("@")
      |> List.first()
      |> to_string()
      |> String.replace(~r/[^a-zA-Z0-9]+/, " ")
      |> String.trim()

    candidate = if String.length(base) < 2, do: "Workspace", else: base
    String.slice(candidate, 0, 120)
  end

  defp billing_customer_attrs(params, %Tenant{} = tenant) do
    {:ok,
     %{
       tenant_id: tenant.id,
       provider: @provider,
       provider_customer_id: Razorpay.customer_id(params),
       email: Razorpay.customer_email(params),
       contact: Razorpay.customer_contact(params)
     }}
  end

  defp provider_subscription_attrs(params, existing_subscription) do
    subscription = Razorpay.subscription_entity(params)
    subscription_id = subscription["id"] || Razorpay.subscription_id(params)

    if is_nil(subscription_id) do
      event_type = Razorpay.event_type(params) || ""

      if String.starts_with?(event_type, "payment.") do
        {:skip, :missing_subscription_id}
      else
        {:error, :missing_subscription_id}
      end
    else
      {:ok,
       %{
         provider: @provider,
         provider_subscription_id: subscription_id,
         provider_customer_id: Razorpay.customer_id(params),
         provider_plan_id: subscription["plan_id"] || Razorpay.plan_id(params),
         provider_status: subscription["status"],
         quantity: subscription["quantity"] || 1,
         current_start_at: Razorpay.timestamp_to_datetime(subscription["current_start"]),
         current_end_at: Razorpay.timestamp_to_datetime(subscription["current_end"]),
         next_charge_at: Razorpay.timestamp_to_datetime(subscription["charge_at"]),
         cancelled_at: Razorpay.timestamp_to_datetime(subscription["cancelled_at"]),
         metadata: provider_metadata(params, existing_subscription)
       }}
    end
  end

  defp tenant_subscription_attrs(params, %Tenant{} = tenant, existing_subscription) do
    subscription = Razorpay.subscription_entity(params)
    subscription_id = subscription["id"] || Razorpay.subscription_id(params)
    provider_plan_id = subscription["plan_id"] || Razorpay.plan_id(params)
    notes = Razorpay.notes(params)

    plan_code =
      Map.get(notes, "plan_id") || Map.get(notes, "plan_code") ||
        plan_code_for(provider_plan_id)

    payment_method = subscription["payment_method"] || Razorpay.payment_entity(params)["method"]

    has_scheduled_changes = subscription["has_scheduled_changes"] || false
    change_scheduled_at = Razorpay.timestamp_to_datetime(subscription["change_scheduled_at"])

    pending_plan_code =
      existing_subscription
      |> then(fn sub -> if sub, do: sub.pending_plan_code, else: nil end)
      |> normalize_pending_plan_code(plan_code, has_scheduled_changes)

    if is_nil(subscription_id) do
      event_type = Razorpay.event_type(params) || ""

      if String.starts_with?(event_type, "payment.") do
        {:skip, :missing_subscription_id}
      else
        {:error, :missing_subscription_id}
      end
    else
      {:ok,
       %{
         tenant_id: tenant.id,
         provider: @provider,
         provider_subscription_id: subscription_id,
         plan_code: plan_code || tenant.plan,
         status: status_from_event(params, subscription),
         quantity: subscription["quantity"] || 1,
         current_start_at: Razorpay.timestamp_to_datetime(subscription["current_start"]),
         current_end_at: Razorpay.timestamp_to_datetime(subscription["current_end"]),
         next_charge_at: Razorpay.timestamp_to_datetime(subscription["charge_at"]),
         cancelled_at: Razorpay.timestamp_to_datetime(subscription["cancelled_at"]),
         grace_expires_at: if(existing_subscription, do: existing_subscription.grace_expires_at),
         payment_method: payment_method,
         has_scheduled_changes: has_scheduled_changes,
         change_scheduled_at: change_scheduled_at,
         pending_plan_code: pending_plan_code,
         short_url: subscription["short_url"],
         metadata: tenant_metadata(params, existing_subscription)
       }}
    end
  end

  defp provider_metadata(params, existing_subscription) do
    metadata = if(existing_subscription, do: existing_subscription.metadata, else: %{})
    Map.put(metadata, "event_type", Razorpay.event_type(params))
  end

  defp tenant_metadata(params, existing_subscription) do
    metadata = if(existing_subscription, do: existing_subscription.metadata, else: %{})

    metadata
    |> Map.put("event_type", Razorpay.event_type(params))
    |> Map.put("provider_status", Razorpay.subscription_entity(params)["status"])
  end

  defp status_from_event(params, subscription) do
    case event_action(Razorpay.event_type(params)) do
      :activate -> "active"
      :charge -> "active"
      :grace -> "pending"
      :pause -> "paused"
      :halt -> "halted"
      :cancel -> "cancelled"
      :complete -> "completed"
      :expire -> "expired"
      _ -> subscription["status"] || "pending"
    end
  end

  defp event_action(event_type) do
    case event_type do
      "subscription.activated" -> :activate
      "subscription.charged" -> :charge
      "payment.captured" -> :charge
      "subscription.resumed" -> :activate
      "subscription.pending" -> :grace
      "payment.failed" -> :grace
      "subscription.halted" -> :halt
      "subscription.paused" -> :pause
      "subscription.cancelled" -> :cancel
      "subscription.completed" -> :complete
      "subscription.expired" -> :expire
      _ -> :ignore
    end
  end

  defp apply_action(:activate, tenant, subscription, _params) do
    _ = Tenants.update_billing_status(tenant, "active")
    _ = clear_grace(subscription)
    _ = ensure_cycle(subscription, tenant)
    :ok
  end

  defp apply_action(:charge, tenant, subscription, _params) do
    _ = Tenants.update_billing_status(tenant, "active")
    _ = clear_grace(subscription)
    _ = ensure_cycle(subscription, tenant)
    :ok
  end

  defp apply_action(:grace, tenant, subscription, _params) do
    grace_expires_at =
      DateTime.add(DateTime.utc_now(), Config.grace_period_days() * 86_400, :second)

    {:ok, subscription} =
      Management.upsert_tenant_subscription(%{
        tenant_id: subscription.tenant_id,
        provider: subscription.provider,
        provider_subscription_id: subscription.provider_subscription_id,
        status: subscription.status,
        grace_expires_at: subscription.grace_expires_at || grace_expires_at
      })

    _ = Tenants.update_billing_status(tenant, "active")
    _ = Notifications.schedule_grace_notifications(subscription)
    _ = Grace.schedule_grace_enforcement(subscription)
    :ok
  end

  defp apply_action(:halt, tenant, subscription, params) do
    _ = apply_action(:grace, tenant, subscription, params)
    :ok
  end

  defp apply_action(:pause, tenant, subscription, params) do
    _ = apply_action(:grace, tenant, subscription, params)
    :ok
  end

  defp apply_action(:cancel, _tenant, subscription, _params) do
    _ = Grace.schedule_end_suspension(subscription)
    :ok
  end

  defp apply_action(:complete, _tenant, subscription, _params) do
    _ = Grace.schedule_end_suspension(subscription)
    :ok
  end

  defp apply_action(:expire, _tenant, subscription, _params) do
    _ = Grace.schedule_end_suspension(subscription)
    :ok
  end

  defp apply_action(:ignore, _tenant, _subscription, _params), do: :ok

  defp ensure_cycle(subscription, tenant) do
    entitlements = Entitlements.effective(tenant)

    case Usage.ensure_cycle(
           subscription,
           subscription.current_start_at,
           subscription.current_end_at,
           entitlements
         ) do
      {:ok, _cycle} ->
        _ = Usage.refresh_phone_numbers(tenant.id)
        _ = Usage.refresh_integrations(tenant.id)

      {:error, _reason} ->
        :ok
    end

    :ok
  end

  defp clear_grace(subscription) do
    if subscription.grace_expires_at do
      Management.upsert_tenant_subscription(%{
        tenant_id: subscription.tenant_id,
        provider: subscription.provider,
        provider_subscription_id: subscription.provider_subscription_id,
        status: subscription.status,
        grace_expires_at: nil
      })
    else
      :ok
    end
  end

  defp maybe_update_plan(tenant, plan_code) when is_binary(plan_code) do
    if tenant.plan != plan_code do
      Tenants.update_billing_plan(tenant, plan_code)
    else
      {:ok, tenant}
    end
  end

  defp maybe_update_plan(_tenant, _plan_code), do: :ok

  defp maybe_send_magic_link(%{user: %User{} = user}) do
    Accounts.deliver_login_instructions(user, &magic_link_url/1)
    :ok
  end

  defp maybe_send_magic_link(_signup), do: :ok

  defp magic_link_url(token) when is_binary(token) do
    SwatiWeb.Endpoint.url() <> "/users/log-in/" <> token
  end

  defp plan_code_for(nil), do: nil

  defp plan_code_for(provider_plan_id) do
    case Plans.get_by_provider_plan_id(@provider, provider_plan_id) do
      %{code: code} -> code
      _ -> nil
    end
  end

  defp existing_subscription(params) do
    subscription_id = Razorpay.subscription_id(params)

    if is_binary(subscription_id) do
      Queries.get_tenant_subscription_by_provider_id(@provider, subscription_id)
    else
      nil
    end
  end

  defp normalize_pending_plan_code(nil, _plan_code, _scheduled?), do: nil

  defp normalize_pending_plan_code(pending_plan_code, plan_code, false)
       when is_binary(pending_plan_code) and pending_plan_code == plan_code,
       do: nil

  defp normalize_pending_plan_code(pending_plan_code, _plan_code, _scheduled?),
    do: pending_plan_code
end
