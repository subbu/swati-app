defmodule Swati.Repo.Migrations.CreateAgentChannels do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:agent_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false

      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all),
        null: false

      add :enabled, :boolean, null: false, default: true
      add :scope, :map, default: %{"mode" => "all"}

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:agent_channels, [:agent_id, :channel_id])

    alter table(:agent_channels) do
      add_if_not_exists :scope, :map, default: %{"mode" => "all"}
    end
  end
end
