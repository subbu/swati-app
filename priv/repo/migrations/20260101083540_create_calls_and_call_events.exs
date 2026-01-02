defmodule Swati.Repo.Migrations.CreateCallsAndCallEvents do
  use Ecto.Migration

  def change do
    create table(:calls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :agent_id, references(:agents, type: :binary_id, on_delete: :nilify_all), null: false
      add :phone_number_id, references(:phone_numbers, type: :binary_id, on_delete: :nilify_all)
      add :provider, :string, null: false
      add :provider_call_id, :string, null: false
      add :provider_stream_id, :string
      add :from_number, :string, null: false
      add :to_number, :string, null: false
      add :status, :string, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :ended_at, :utc_datetime_usec
      add :duration_seconds, :integer
      add :recording, :map
      add :transcript, :map
      add :summary, :text
      add :disposition, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:calls, [:tenant_id])
    create index(:calls, [:agent_id])
    create index(:calls, [:phone_number_id])
    create index(:calls, [:tenant_id, :started_at])
    create unique_index(:calls, [:provider, :provider_call_id])

    create table(:call_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :call_id, references(:calls, type: :binary_id, on_delete: :delete_all), null: false
      add :ts, :utc_datetime_usec, null: false
      add :type, :string, null: false
      add :payload, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:call_events, [:call_id])
    create index(:call_events, [:call_id, :ts])
  end
end
