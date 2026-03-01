defmodule Swati.Inbound.CommandsTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Inbound
  alias Swati.Inbound.Secrets

  test "update_connector updates signing secret without FK errors" do
    scope = user_scope_fixture()

    {:ok, connector} =
      Inbound.create_connector(scope.tenant.id, %{
        name: "Resend Connector",
        signing_secret: "whsec_initial",
        default_endpoint_address: "support@tenant.test"
      })

    assert is_binary(connector.signing_secret_id)
    assert Secrets.get_secret_value(connector.signing_secret_id) == "whsec_initial"

    assert {:ok, updated_connector} =
             Inbound.update_connector(connector, %{signing_secret: "whsec_rotated"})

    assert updated_connector.signing_secret_id == connector.signing_secret_id
    assert Secrets.get_secret_value(updated_connector.signing_secret_id) == "whsec_rotated"
  end
end
