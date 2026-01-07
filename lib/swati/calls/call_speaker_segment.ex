defmodule Swati.Calls.CallSpeakerSegment do
  use Swati.DbSchema

  schema "call_speaker_segments" do
    field :speaker, :string
    field :start_ms, :integer
    field :end_ms, :integer
    field :energy_avg, :float

    belongs_to :call, Swati.Calls.Call

    timestamps()
  end

  def changeset(segment, attrs) do
    segment
    |> cast(attrs, [:call_id, :speaker, :start_ms, :end_ms, :energy_avg])
    |> validate_required([:call_id, :speaker, :start_ms, :end_ms])
  end
end
