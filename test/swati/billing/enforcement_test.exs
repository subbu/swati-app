defmodule Swati.Billing.EnforcementTest do
  use Swati.DataCase, async: true

  alias Swati.AccountsFixtures
  alias Swati.Billing
  alias Swati.Integrations.Integration
  alias Swati.Repo
  alias Swati.Telephony.PhoneNumber

  test "enforces phone number limits" do
    scope = AccountsFixtures.user_scope_fixture()
    tenant = scope.tenant

    %PhoneNumber{}
    |> PhoneNumber.changeset(%{
      tenant_id: tenant.id,
      provider: :plivo,
      e164: "+14155550123",
      country: "US",
      status: :active
    })
    |> Repo.insert!()

    assert {:error, :phone_number_limit_reached} = Billing.ensure_phone_number_limit(tenant.id)
  end

  test "enforces integration limits" do
    scope = AccountsFixtures.user_scope_fixture()
    tenant = scope.tenant

    %Integration{}
    |> Integration.changeset(%{
      tenant_id: tenant.id,
      type: :mcp_streamable_http,
      name: "Test Integration",
      endpoint_url: "https://example.com/mcp",
      origin: "https://example.com",
      protocol_version: "2025-06-18",
      timeout_secs: 15,
      status: :active,
      allowed_tools: [],
      auth_type: :none
    })
    |> Repo.insert!()

    assert {:error, :integration_limit_reached} = Billing.ensure_integration_limit(tenant.id)
  end
end
