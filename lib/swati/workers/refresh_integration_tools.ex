defmodule Swati.Workers.RefreshIntegrationTools do
  use Oban.Worker, queue: :integrations

  alias Swati.Integrations

  @impl true
  def perform(%Oban.Job{args: %{"integration_id" => integration_id}}) do
    integration = Swati.Repo.get!(Swati.Integrations.Integration, integration_id)
    _ = Integrations.test_integration(integration)
    :ok
  end

  def perform(%Oban.Job{}), do: :ok
end
