defmodule Swati.Sessions.SessionUtterance do
  use Swati.DbSchema

  schema "session_utterances" do
    field :speaker, :string
    field :start_ms, :integer
    field :end_ms, :integer
    field :text, :string
    field :event_indexes, {:array, :integer}

    belongs_to :session, Swati.Sessions.Session

    timestamps()
  end

  def changeset(utterance, attrs) do
    utterance
    |> cast(attrs, [:session_id, :speaker, :start_ms, :end_ms, :text, :event_indexes])
    |> validate_required([:session_id, :speaker, :start_ms, :end_ms, :text])
  end
end
