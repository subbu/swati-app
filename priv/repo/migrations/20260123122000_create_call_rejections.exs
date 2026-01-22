defmodule Swati.Repo.Migrations.CreateCallRejections do
  use Ecto.Migration

  def change do
    create table(:call_rejections) do
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, type: :binary_id, on_delete: :nilify_all)
      add :endpoint_id, references(:endpoints, type: :binary_id, on_delete: :nilify_all)
      add :provider, :string, null: false
      add :provider_call_id, :string
      add :session_external_id, :string
      add :from_address, :string
      add :to_address, :string
      add :direction, :string
      add :reason_code, :string, null: false
      add :reason_message, :string
      add :action, :string
      add :retryable, :boolean, null: false, default: false
      add :details, :map

      timestamps()
    end

    create index(:call_rejections, [:tenant_id])
    create index(:call_rejections, [:tenant_id, :reason_code])
    create index(:call_rejections, [:tenant_id, :inserted_at])
    create index(:call_rejections, [:endpoint_id])

    create unique_index(:call_rejections, [:provider, :provider_call_id, :reason_code],
             where: "provider_call_id IS NOT NULL"
           )
  end
end
