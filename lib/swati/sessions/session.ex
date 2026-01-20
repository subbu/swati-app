defmodule Swati.Sessions.Session do
  use Swati.DbSchema

  @statuses [:open, :active, :waiting_on_customer, :closed]
  @directions [:inbound, :outbound]

  schema "sessions" do
    field :status, Ecto.Enum, values: @statuses, default: :open
    field :direction, Ecto.Enum, values: @directions
    field :external_id, :string
    field :subject, :string
    field :started_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :last_event_at, :utc_datetime_usec
    field :metadata, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :channel, Swati.Channels.Channel
    belongs_to :endpoint, Swati.Channels.Endpoint
    belongs_to :customer, Swati.Customers.Customer
    belongs_to :case, Swati.Cases.Case
    belongs_to :agent, Swati.Agents.Agent

    has_many :events, Swati.Sessions.SessionEvent
    has_many :artifacts, Swati.Sessions.SessionArtifact

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :tenant_id,
      :channel_id,
      :endpoint_id,
      :customer_id,
      :case_id,
      :agent_id,
      :status,
      :direction,
      :external_id,
      :subject,
      :started_at,
      :ended_at,
      :last_event_at,
      :metadata
    ])
    |> validate_required([:tenant_id, :status])
    |> unique_constraint([:endpoint_id, :external_id])
  end
end
