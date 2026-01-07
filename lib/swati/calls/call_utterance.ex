defmodule Swati.Calls.CallUtterance do
  use Swati.DbSchema

  schema "call_utterances" do
    field :speaker, :string
    field :start_ms, :integer
    field :end_ms, :integer
    field :text, :string
    field :event_indexes, {:array, :integer}

    belongs_to :call, Swati.Calls.Call

    timestamps()
  end

  def changeset(utterance, attrs) do
    utterance
    |> cast(attrs, [:call_id, :speaker, :start_ms, :end_ms, :text, :event_indexes])
    |> validate_required([:call_id, :speaker, :start_ms, :end_ms, :text])
  end
end
