defmodule Swati.Workers.RefreshWhatsAppTokens do
  use Oban.Worker, queue: :channels, max_attempts: 3

  alias Swati.Channels.WhatsApp

  @impl Oban.Worker
  def perform(_job) do
    WhatsApp.refresh_tokens()
  end
end
