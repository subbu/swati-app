defmodule Swati.Integrations.ManagementTest do
  use Swati.DataCase

  import Swati.AccountsFixtures

  alias Swati.Integrations
  alias Swati.Integrations.Secret

  setup do
    scope = user_scope_fixture()
    {:ok, scope: scope}
  end

  test "create integration normalizes allowed_tools and defaults type", %{scope: scope} do
    attrs = %{
      "name" => "Search",
      "endpoint_url" => "https://example.com/mcp",
      "allowed_tools" => "a,b\nc",
      "type" => ""
    }

    assert {:ok, integration} =
             Integrations.create_integration(scope.tenant.id, attrs, scope.user)

    assert integration.allowed_tools == ["a", "b", "c"]
    assert integration.type == :mcp_streamable_http
  end

  test "create integration requires auth token for bearer", %{scope: scope} do
    attrs = %{
      "name" => "Secure",
      "endpoint_url" => "https://example.com/mcp",
      "auth_type" => :bearer
    }

    assert {:error, "auth_token_required"} =
             Integrations.create_integration(scope.tenant.id, attrs, scope.user)
  end

  test "update integration preserves bearer secret when auth token missing", %{scope: scope} do
    attrs = %{
      "name" => "Secure",
      "endpoint_url" => "https://example.com/mcp",
      "auth_type" => :bearer,
      "auth_token" => "tok-1"
    }

    assert {:ok, integration} =
             Integrations.create_integration(scope.tenant.id, attrs, scope.user)

    secret_id = integration.auth_secret_id
    assert is_binary(secret_id)

    assert {:ok, updated} =
             Integrations.update_integration(
               integration,
               %{"name" => "Secure", "auth_type" => :bearer},
               scope.user
             )

    assert updated.auth_secret_id == secret_id
    assert %Secret{value: "tok-1"} = Repo.get!(Secret, secret_id)
  end
end
