defmodule Swati.Workers.SyncChannelConnections do
  use Oban.Worker, queue: :channels, max_attempts: 1

  alias Swati.Channels

  @impl true
  def perform(%Oban.Job{}) do
    cutoff = sync_cutoff()

    Channels.list_syncable_connections(cutoff)
    |> Enum.each(fn connection ->
      _ = Channels.enqueue_sync_connection(connection)
    end)

    :ok
  end

  defp sync_cutoff do
    seconds = Channels.sync_interval_seconds()
    DateTime.add(DateTime.utc_now(), -seconds, :second)
  end
end
