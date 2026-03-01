defmodule Swati.Workers.ProcessInboundDelivery do
  use Oban.Worker, queue: :channels, max_attempts: 5

  alias Swati.Inbound

  @impl true
  def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) when is_binary(delivery_id) do
    case Inbound.process_delivery(delivery_id) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  def perform(%Oban.Job{}), do: :ok
end
