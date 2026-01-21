defmodule Swati.CustomersTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Channels
  alias Swati.Customers

  defp unique_phone do
    "+1555#{System.unique_integer([:positive])}"
  end

  test "resolve_customer creates and reuses identities" do
    scope = user_scope_fixture()
    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    phone = unique_phone()

    {:ok, customer, identity} =
      Customers.resolve_customer(scope.tenant.id, channel.id, :phone, %{address: phone})

    assert customer.primary_phone == phone
    assert identity.address == phone

    {:ok, same_customer, _identity} =
      Customers.resolve_customer(scope.tenant.id, channel.id, :phone, %{address: phone})

    assert same_customer.id == customer.id
  end

  test "resolve_customer links identity across channels by address" do
    scope = user_scope_fixture()
    {:ok, voice} = Channels.ensure_voice_channel(scope.tenant.id)

    {:ok, whatsapp} =
      Channels.create_channel(scope.tenant.id, %{
        name: "WhatsApp",
        key: "whatsapp",
        type: :whatsapp,
        status: :active,
        capabilities: %{}
      })

    phone = unique_phone()

    {:ok, customer, _identity} =
      Customers.resolve_customer(scope.tenant.id, voice.id, :phone, %{address: phone})

    {:ok, same_customer, identity} =
      Customers.resolve_customer(scope.tenant.id, whatsapp.id, :phone, %{address: phone})

    assert same_customer.id == customer.id
    assert identity.channel_id == whatsapp.id
  end
end
