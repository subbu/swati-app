defmodule Swati.Sessions.SessionSpeakerSegment do
  use Swati.DbSchema

  schema "session_speaker_segments" do
    field :speaker, :string
    field :start_ms, :integer
    field :end_ms, :integer
    field :energy_avg, :float

    belongs_to :session, Swati.Sessions.Session

    timestamps()
  end

  def changeset(segment, attrs) do
    segment
    |> cast(attrs, [:session_id, :speaker, :start_ms, :end_ms, :energy_avg])
    |> validate_required([:session_id, :speaker, :start_ms, :end_ms])
  end
end
