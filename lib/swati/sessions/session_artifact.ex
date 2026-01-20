defmodule Swati.Sessions.SessionArtifact do
  use Swati.DbSchema

  schema "session_artifacts" do
    field :kind, :string
    field :payload, :map

    belongs_to :session, Swati.Sessions.Session

    timestamps()
  end

  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [:session_id, :kind, :payload])
    |> validate_required([:session_id, :kind])
  end
end
