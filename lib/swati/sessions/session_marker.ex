defmodule Swati.Sessions.SessionMarker do
  use Swati.DbSchema

  schema "session_markers" do
    field :kind, :string
    field :offset_ms, :integer
    field :payload, :map

    belongs_to :session, Swati.Sessions.Session

    timestamps()
  end

  def changeset(marker, attrs) do
    marker
    |> cast(attrs, [:session_id, :kind, :offset_ms, :payload])
    |> validate_required([:session_id, :kind, :offset_ms])
  end
end
