defmodule Swati.Repo.Migrations.CreatePhoneNumbers do
  use Ecto.Migration

  def change do
    create table(:phone_numbers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string, null: false, default: "plivo"
      add :e164, :string, null: false
      add :country, :string, null: false
      add :region, :string
      add :status, :string, null: false, default: "provisioned"
      add :inbound_agent_id, references(:agents, type: :binary_id, on_delete: :nilify_all)
      add :provider_number_id, :string
      add :provider_app_id, :string
      add :answer_url, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:phone_numbers, [:e164])
    create index(:phone_numbers, [:tenant_id])
    create index(:phone_numbers, [:tenant_id, :inbound_agent_id])
  end
end
