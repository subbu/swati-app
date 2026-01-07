defmodule Swati.Calls.CallTimelineMeta do
  use Swati.DbSchema

  schema "call_timeline_meta" do
    field :origin_ts, :utc_datetime_usec
    field :origin_type, :string
    field :duration_ms, :integer
    field :version, :integer
    field :built_at, :utc_datetime_usec

    belongs_to :call, Swati.Calls.Call

    timestamps()
  end

  def changeset(meta, attrs) do
    meta
    |> cast(attrs, [:call_id, :origin_ts, :origin_type, :duration_ms, :version, :built_at])
    |> validate_required([:call_id, :origin_ts, :origin_type, :version])
  end
end
