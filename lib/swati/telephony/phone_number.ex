defmodule Swati.Telephony.PhoneNumber do
  use Swati.DbSchema

  @providers [:plivo]
  @statuses [:provisioned, :active, :suspended, :released]

  schema "phone_numbers" do
    field :provider, Ecto.Enum, values: @providers, default: :plivo
    field :e164, :string
    field :country, :string
    field :region, :string
    field :status, Ecto.Enum, values: @statuses, default: :provisioned
    field :provider_number_id, :string
    field :provider_app_id, :string
    field :answer_url, :string

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :inbound_agent, Swati.Agents.Agent
    has_one :endpoint, Swati.Channels.Endpoint, foreign_key: :phone_number_id

    timestamps()
  end

  def changeset(phone_number, attrs) do
    phone_number
    |> cast(attrs, [
      :tenant_id,
      :provider,
      :e164,
      :country,
      :region,
      :status,
      :inbound_agent_id,
      :provider_number_id,
      :provider_app_id,
      :answer_url
    ])
    |> validate_required([:tenant_id, :provider, :e164, :country, :status])
    |> validate_length(:e164, min: 6, max: 32)
    |> unique_constraint(:e164)
  end
end
