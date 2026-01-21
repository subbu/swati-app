defmodule Swati.Workers.SyncChannelConnection do
  use Oban.Worker, queue: :channels, max_attempts: 3

  alias Swati.Channels
  alias Swati.Repo

  @impl true
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "connection_id" => connection_id}}) do
    connection =
      tenant_id
      |> Channels.get_connection!(connection_id)
      |> Repo.preload([:channel, :endpoint])

    case Channels.sync_connection(connection) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def perform(%Oban.Job{}), do: :ok
end
