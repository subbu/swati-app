defmodule Swati.Calls.Call do
  use Swati.DbSchema

  @providers [:plivo]
  @statuses [:started, :in_progress, :ended, :failed, :cancelled, :error]

  schema "calls" do
    field :provider, Ecto.Enum, values: @providers
    field :provider_call_id, :string
    field :provider_stream_id, :string
    field :from_number, :string
    field :to_number, :string
    field :status, Ecto.Enum, values: @statuses
    field :started_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :duration_seconds, :integer
    field :recording, :map
    field :transcript, :map
    field :summary, :string
    field :disposition, :string

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :agent, Swati.Agents.Agent
    belongs_to :phone_number, Swati.Telephony.PhoneNumber

    has_many :events, Swati.Calls.CallEvent

    timestamps()
  end

  def changeset(call, attrs) do
    call
    |> cast(attrs, [
      :tenant_id,
      :agent_id,
      :phone_number_id,
      :provider,
      :provider_call_id,
      :provider_stream_id,
      :from_number,
      :to_number,
      :status,
      :started_at,
      :ended_at,
      :duration_seconds,
      :recording,
      :transcript,
      :summary,
      :disposition
    ])
    |> validate_required([
      :tenant_id,
      :agent_id,
      :provider,
      :provider_call_id,
      :from_number,
      :to_number,
      :status,
      :started_at
    ])
  end
end
