defmodule Swati.Repo.Migrations.CreateAgentsAndVersions do
  use Ecto.Migration

  def change do
    create table(:agents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :language, :string, null: false, default: "en-IN"
      add :voice_provider, :string, null: false, default: "google"
      add :voice_name, :string, null: false, default: "Fenrir"
      add :llm_provider, :string, null: false, default: "google"
      add :llm_model, :string, null: false
      add :prompt_blocks, :map, null: false
      add :tool_policy, :map, null: false
      add :escalation_policy, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:agents, [:tenant_id])
    create unique_index(:agents, [:tenant_id, :name])

    create table(:agent_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :version, :integer, null: false
      add :config, :map, null: false
      add :published_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:agent_versions, [:agent_id])
    create unique_index(:agent_versions, [:agent_id, :version])

    alter table(:agents) do
      add :published_version_id,
          references(:agent_versions, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
