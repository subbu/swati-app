defmodule Swati.Repo.Migrations.CreateWhatsappTemplateMessages do
  use Ecto.Migration

  def change do
    create table(:whatsapp_template_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :connection_id,
          references(:channel_connections, type: :binary_id, on_delete: :delete_all),
          null: false

      add :waba_id, :string
      add :phone_number_id, :string
      add :recipient, :string, null: false
      add :template_name, :string, null: false
      add :template_language, :string, null: false
      add :meta_message_id, :string
      add :status, :string, null: false, default: "queued"
      add :status_events, :map, null: false, default: %{}
      add :provider_response, :map, null: false, default: %{}
      add :template_payload, :map, null: false, default: %{}
      add :sent_at, :utc_datetime_usec
      add :delivered_at, :utc_datetime_usec
      add :read_at, :utc_datetime_usec
      add :failed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:whatsapp_template_messages, [:tenant_id])
    create index(:whatsapp_template_messages, [:connection_id])
    create index(:whatsapp_template_messages, [:status])
    create index(:whatsapp_template_messages, [:inserted_at])
    create index(:whatsapp_template_messages, [:meta_message_id])

    create unique_index(:whatsapp_template_messages, [:tenant_id, :meta_message_id])
  end
end
