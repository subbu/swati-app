defmodule Swati.Calls.CallEvent do
  use Swati.DbSchema

  schema "call_events" do
    field :ts, :utc_datetime_usec
    field :type, :string
    field :payload, :map

    belongs_to :call, Swati.Calls.Call

    timestamps()
  end

  def changeset(call_event, attrs) do
    call_event
    |> cast(attrs, [:call_id, :ts, :type, :payload])
    |> validate_required([:call_id, :ts, :type])
  end
end
