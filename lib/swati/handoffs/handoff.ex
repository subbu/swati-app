defmodule Swati.Handoffs.Handoff do
  use Swati.DbSchema

  @statuses [:requested, :accepted, :declined, :ended]

  schema "handoffs" do
    field :status, Ecto.Enum, values: @statuses, default: :requested
    field :requested_by_type, :string
    field :requested_by_id, :string
    field :requested_at, :utc_datetime_usec
    field :resolved_at, :utc_datetime_usec
    field :metadata, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :case, Swati.Cases.Case
    belongs_to :session, Swati.Sessions.Session
    belongs_to :target_channel, Swati.Channels.Channel
    belongs_to :target_endpoint, Swati.Channels.Endpoint

    timestamps()
  end

  def changeset(handoff, attrs) do
    handoff
    |> cast(attrs, [
      :tenant_id,
      :case_id,
      :session_id,
      :status,
      :requested_by_type,
      :requested_by_id,
      :requested_at,
      :resolved_at,
      :metadata,
      :target_channel_id,
      :target_endpoint_id
    ])
    |> validate_required([:tenant_id, :status, :requested_by_type])
  end
end
