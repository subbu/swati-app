defmodule Swati.Repo.Migrations.CreateCallTimelines do
  use Ecto.Migration

  def change do
    create table(:call_timeline_meta, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :call_id, references(:calls, type: :binary_id, on_delete: :delete_all), null: false
      add :origin_ts, :utc_datetime_usec, null: false
      add :origin_type, :string, null: false
      add :duration_ms, :integer
      add :version, :integer, null: false, default: 1
      add :built_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:call_timeline_meta, [:call_id])

    create table(:call_utterances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :call_id, references(:calls, type: :binary_id, on_delete: :delete_all), null: false
      add :speaker, :string, null: false
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :text, :text, null: false
      add :event_indexes, {:array, :integer}

      timestamps()
    end

    create index(:call_utterances, [:call_id, :start_ms])
    create index(:call_utterances, [:call_id, :end_ms])

    create table(:call_speaker_segments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :call_id, references(:calls, type: :binary_id, on_delete: :delete_all), null: false
      add :speaker, :string, null: false
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :energy_avg, :float

      timestamps()
    end

    create index(:call_speaker_segments, [:call_id, :start_ms])

    create table(:call_tool_calls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :call_id, references(:calls, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :status, :string, null: false
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :latency_ms, :integer
      add :args, :map
      add :response_summary, :text
      add :mcp_endpoint, :string
      add :mcp_session_id, :string

      timestamps()
    end

    create index(:call_tool_calls, [:call_id, :start_ms])

    create table(:call_markers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :call_id, references(:calls, type: :binary_id, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :offset_ms, :integer, null: false
      add :payload, :map

      timestamps()
    end

    create index(:call_markers, [:call_id, :offset_ms])
  end
end
