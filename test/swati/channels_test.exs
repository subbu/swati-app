defmodule Swati.ChannelsTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Channels
  alias Swati.Repo
  alias Swati.Telephony.PhoneNumber

  defp unique_phone do
    "+1555#{System.unique_integer([:positive])}"
  end

  test "ensure_voice_channel creates default channel" do
    scope = user_scope_fixture()

    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    assert channel.key == "voice"
    assert channel.type == :voice
  end

  test "ensure_endpoint_for_phone_number creates endpoint" do
    scope = user_scope_fixture()

    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    {:ok, phone_number} =
      %PhoneNumber{}
      |> PhoneNumber.changeset(%{
        tenant_id: scope.tenant.id,
        provider: :plivo,
        e164: unique_phone(),
        country: "US",
        status: :provisioned
      })
      |> Repo.insert()

    {:ok, endpoint} = Channels.ensure_endpoint_for_phone_number(phone_number)

    assert endpoint.channel_id == channel.id
    assert endpoint.address == phone_number.e164

    fetched = Channels.get_endpoint_by_phone_number_id(scope.tenant.id, phone_number.id)
    assert fetched.id == endpoint.id
  end
end
