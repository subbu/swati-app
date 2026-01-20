defmodule Swati.Repo.Migrations.CreateSessionsAndEvents do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :channel_id, references(:channels, type: :binary_id, on_delete: :nilify_all)
      add :endpoint_id, references(:endpoints, type: :binary_id, on_delete: :nilify_all)
      add :customer_id, references(:customers, type: :binary_id, on_delete: :nilify_all)
      add :case_id, references(:cases, type: :binary_id, on_delete: :nilify_all)
      add :agent_id, references(:agents, type: :binary_id, on_delete: :nilify_all)

      add :status, :string, null: false, default: "open"
      add :direction, :string
      add :external_id, :string
      add :subject, :string
      add :started_at, :utc_datetime_usec
      add :ended_at, :utc_datetime_usec
      add :last_event_at, :utc_datetime_usec
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:sessions, [:tenant_id])
    create index(:sessions, [:case_id])
    create index(:sessions, [:endpoint_id])
    create index(:sessions, [:channel_id])
    create index(:sessions, [:status])
    create index(:sessions, [:external_id])
    create unique_index(:sessions, [:endpoint_id, :external_id])

    create table(:session_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :ts, :utc_datetime_usec, null: false
      add :type, :string, null: false
      add :source, :string
      add :idempotency_key, :string
      add :payload, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:session_events, [:session_id])
    create index(:session_events, [:session_id, :ts])
    create index(:session_events, [:idempotency_key])
    create unique_index(:session_events, [:session_id, :idempotency_key])
  end
end
