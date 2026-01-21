defmodule Mix.Tasks.Swati.SimulateUseCases do
  use Mix.Task

  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Tenancy.Tenant
  alias Swati.UseCases.Simulator

  @shortdoc "Simulate omnichannel use cases"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    case fetch_tenant_id() do
      nil ->
        Mix.shell().error("No tenant found. Create a tenant first.")

      tenant_id ->
        _ = Simulator.run(tenant_id)
        Mix.shell().info("Use-case simulation complete.")
    end
  end

  defp fetch_tenant_id do
    from(t in Tenant, order_by: [asc: t.inserted_at], limit: 1)
    |> Repo.one()
    |> case do
      nil -> nil
      tenant -> tenant.id
    end
  end
end
