defmodule Swati.Sessions.SessionEvent do
  use Swati.DbSchema

  schema "session_events" do
    field :ts, :utc_datetime_usec
    field :type, :string
    field :category, :string, default: "system"
    field :source, :string
    field :idempotency_key, :string
    field :payload, :map

    belongs_to :session, Swati.Sessions.Session

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:session_id, :ts, :type, :category, :source, :idempotency_key, :payload])
    |> validate_required([:session_id, :ts, :type, :category])
    |> unique_constraint([:session_id, :idempotency_key])
  end
end
