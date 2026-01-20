defmodule Swati.Repo.Migrations.CreateApprovalsAndHandoffs do
  use Ecto.Migration

  def change do
    create table(:approvals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :case_id, references(:cases, type: :binary_id, on_delete: :nilify_all)
      add :session_id, references(:sessions, type: :binary_id, on_delete: :nilify_all)

      add :status, :string, null: false, default: "pending"
      add :requested_by_type, :string, null: false
      add :requested_by_id, :string
      add :decision_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :requested_at, :utc_datetime_usec
      add :resolved_at, :utc_datetime_usec
      add :request_payload, :map
      add :decision_payload, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:approvals, [:tenant_id])
    create index(:approvals, [:case_id])
    create index(:approvals, [:session_id])
    create index(:approvals, [:status])

    create table(:handoffs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :case_id, references(:cases, type: :binary_id, on_delete: :nilify_all)
      add :session_id, references(:sessions, type: :binary_id, on_delete: :nilify_all)

      add :status, :string, null: false, default: "requested"
      add :requested_by_type, :string, null: false
      add :requested_by_id, :string
      add :target_channel_id, references(:channels, type: :binary_id, on_delete: :nilify_all)
      add :target_endpoint_id, references(:endpoints, type: :binary_id, on_delete: :nilify_all)
      add :requested_at, :utc_datetime_usec
      add :resolved_at, :utc_datetime_usec
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:handoffs, [:tenant_id])
    create index(:handoffs, [:case_id])
    create index(:handoffs, [:session_id])
    create index(:handoffs, [:status])
  end
end
