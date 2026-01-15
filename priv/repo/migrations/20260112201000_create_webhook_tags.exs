defmodule Swati.Repo.Migrations.CreateWebhookTags do
  use Ecto.Migration

  def change do
    create table(:tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :color, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:tags, [:tenant_id])
    create unique_index(:tags, [:tenant_id, :slug])

    execute(
      "CREATE UNIQUE INDEX tags_tenant_id_lower_name_index ON tags (tenant_id, lower(name))",
      "DROP INDEX tags_tenant_id_lower_name_index"
    )

    create table(:webhook_tags, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :webhook_id, references(:webhooks, type: :binary_id, on_delete: :delete_all),
        null: false

      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:webhook_tags, [:webhook_id, :tag_id])
    create index(:webhook_tags, [:tag_id])
  end
end
