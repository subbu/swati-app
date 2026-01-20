defmodule Swati.Channels.Commands do
  alias Swati.Channels.Channel
  alias Swati.Channels.Endpoint
  alias Swati.Channels.Queries
  alias Swati.Repo

  def create_channel(tenant_id, attrs) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("tenant_id", tenant_id)

    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  def ensure_channel(tenant_id, attrs) do
    key = Map.get(attrs, :key) || Map.get(attrs, "key")

    case Queries.get_channel_by_key(tenant_id, to_string(key)) do
      nil -> create_channel(tenant_id, attrs)
      channel -> {:ok, channel}
    end
  end

  def ensure_voice_channel(tenant_id) do
    ensure_channel(tenant_id, %{
      "name" => "Voice",
      "key" => "voice",
      "type" => :voice,
      "status" => :active,
      "capabilities" => default_voice_capabilities()
    })
  end

  def ensure_endpoint_for_phone_number(phone_number) do
    with {:ok, channel} <- ensure_voice_channel(phone_number.tenant_id) do
      attrs = %{
        tenant_id: phone_number.tenant_id,
        channel_id: channel.id,
        address: phone_number.e164,
        display_name: phone_number.e164,
        status: :active,
        routing_policy: %{"default_agent_id" => phone_number.inbound_agent_id},
        metadata: %{
          "provider" => phone_number.provider,
          "country" => phone_number.country,
          "region" => phone_number.region
        },
        phone_number_id: phone_number.id
      }

      changeset = Endpoint.changeset(%Endpoint{}, attrs)

      Repo.insert(
        changeset,
        on_conflict:
          {:replace, [:address, :display_name, :status, :routing_policy, :metadata, :updated_at]},
        conflict_target: [:phone_number_id],
        returning: true
      )
      |> case do
        {:ok, endpoint} -> {:ok, endpoint}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def update_endpoint_routing(%Endpoint{} = endpoint, routing_policy)
      when is_map(routing_policy) do
    endpoint
    |> Endpoint.changeset(%{routing_policy: routing_policy})
    |> Repo.update()
  end

  defp default_voice_capabilities do
    %{
      "supports" => %{
        "sync" => true,
        "attachments" => false,
        "multi_party" => false,
        "message_edits" => false,
        "typing" => false
      },
      "tools" => [
        "channel.message.send",
        "channel.thread.fetch",
        "channel.thread.close",
        "channel.handoff.request",
        "channel.handoff.transfer"
      ]
    }
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end
end
