defmodule Swati.Workers.SyncPhoneNumberStatus do
  use Oban.Worker, queue: :telephony

  @impl true
  def perform(%Oban.Job{}) do
    :ok
  end
end
