defmodule Swati.Inbound.ThreadOwnershipEvent do
  use Swati.DbSchema

  schema "inbound_thread_ownership_events" do
    field :thread_key, :string
    field :reason, :string
    field :source, :string
    field :metadata, :map
    field :resolved_at, :utc_datetime_usec

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :session, Swati.Sessions.Session
    belongs_to :delivery, Swati.Inbound.Delivery
    belongs_to :previous_agent, Swati.Agents.Agent
    belongs_to :owner_agent, Swati.Agents.Agent

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :tenant_id,
      :session_id,
      :delivery_id,
      :thread_key,
      :previous_agent_id,
      :owner_agent_id,
      :reason,
      :source,
      :metadata,
      :resolved_at
    ])
    |> validate_required([
      :tenant_id,
      :session_id,
      :thread_key,
      :owner_agent_id,
      :reason,
      :source,
      :resolved_at
    ])
  end
end
