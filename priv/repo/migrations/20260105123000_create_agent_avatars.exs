defmodule Swati.Repo.Migrations.CreateAgentAvatars do
  use Ecto.Migration

  def change do
    create table(:agent_avatars, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :status, :string, null: false
      add :prompt, :string
      add :params, :map, null: false, default: %{}
      add :prediction_id, :string
      add :source_url, :string
      add :output_url, :string
      add :error, :string
      add :generated_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:agent_avatars, [:tenant_id])
    create index(:agent_avatars, [:agent_id])
    create index(:agent_avatars, [:agent_id, :inserted_at])
    create index(:agent_avatars, [:status])
  end
end
