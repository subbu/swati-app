defmodule Swati.Billing.Enforcement do
  alias Swati.Billing.Entitlements
  alias Swati.Integrations
  alias Swati.Telephony
  alias Swati.Tenancy

  def ensure_phone_number_limit(tenant_id) do
    tenant = Tenancy.get_tenant!(tenant_id)
    entitlements = Entitlements.effective(tenant)
    limit = Entitlements.max_phone_numbers(entitlements)

    if limit do
      count = Telephony.count_phone_numbers(tenant_id)
      if count >= limit, do: {:error, :phone_number_limit_reached}, else: :ok
    else
      :ok
    end
  end

  def ensure_integration_limit(tenant_id) do
    tenant = Tenancy.get_tenant!(tenant_id)
    entitlements = Entitlements.effective(tenant)
    limit = Entitlements.max_integrations(entitlements)

    if limit do
      count = Integrations.count_integrations(tenant_id)
      if count >= limit, do: {:error, :integration_limit_reached}, else: :ok
    else
      :ok
    end
  end
end
