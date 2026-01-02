defmodule Swati.Repo.Migrations.CreateAgentIntegrations do
  use Ecto.Migration

  def change do
    create table(:agent_integrations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false

      add :integration_id, references(:integrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:agent_integrations, [:agent_id, :integration_id])
  end
end
