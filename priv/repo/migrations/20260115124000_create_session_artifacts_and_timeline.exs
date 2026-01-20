defmodule Swati.Repo.Migrations.CreateSessionArtifactsAndTimeline do
  use Ecto.Migration

  def change do
    create table(:session_artifacts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :kind, :string, null: false
      add :payload, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:session_artifacts, [:session_id])
    create index(:session_artifacts, [:kind])

    create table(:session_timeline_meta, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :origin_ts, :utc_datetime_usec
      add :origin_type, :string
      add :duration_ms, :integer
      add :version, :integer
      add :built_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:session_timeline_meta, [:session_id])

    create table(:session_utterances, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :speaker, :string, null: false
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :text, :text, null: false
      add :event_indexes, {:array, :integer}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:session_utterances, [:session_id])

    create table(:session_speaker_segments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :speaker, :string, null: false
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :energy_avg, :float

      timestamps(type: :utc_datetime_usec)
    end

    create index(:session_speaker_segments, [:session_id])

    create table(:session_tool_calls, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :status, :string, null: false
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :latency_ms, :integer
      add :args, :map
      add :response_summary, :text
      add :mcp_endpoint, :string
      add :mcp_session_id, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:session_tool_calls, [:session_id])

    create table(:session_markers, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :kind, :string, null: false
      add :offset_ms, :integer, null: false
      add :payload, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:session_markers, [:session_id])
  end
end
