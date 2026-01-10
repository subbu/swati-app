defmodule Swati.Agents.AgentAvatar do
  use Swati.DbSchema

  @providers [:replicate]
  @statuses [:queued, :running, :ready, :failed]

  schema "agent_avatars" do
    field :provider, Ecto.Enum, values: @providers, default: :replicate
    field :status, Ecto.Enum, values: @statuses, default: :queued
    field :prompt, :string
    field :params, :map, default: %{}
    field :prediction_id, :string
    field :source_url, :string
    field :output_url, :string
    field :error, :string
    field :generated_at, :utc_datetime_usec

    belongs_to :agent, Swati.Agents.Agent
    belongs_to :tenant, Swati.Tenancy.Tenant

    timestamps()
  end

  def changeset(avatar, attrs) do
    avatar
    |> cast(attrs, [
      :tenant_id,
      :agent_id,
      :provider,
      :status,
      :prompt,
      :params,
      :prediction_id,
      :source_url,
      :output_url,
      :error,
      :generated_at
    ])
    |> validate_required([:tenant_id, :agent_id, :provider, :status])
  end
end
