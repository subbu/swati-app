defmodule Swati.Calls.CallMarker do
  use Swati.DbSchema

  schema "call_markers" do
    field :kind, :string
    field :offset_ms, :integer
    field :payload, :map

    belongs_to :call, Swati.Calls.Call

    timestamps()
  end

  def changeset(marker, attrs) do
    marker
    |> cast(attrs, [:call_id, :kind, :offset_ms, :payload])
    |> validate_required([:call_id, :kind, :offset_ms])
  end
end
