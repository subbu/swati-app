defmodule Swati.Calls.CallRejection do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "call_rejections" do
    field :provider, :string
    field :provider_call_id, :string
    field :session_external_id, :string
    field :from_address, :string
    field :to_address, :string
    field :direction, :string
    field :reason_code, :string
    field :reason_message, :string
    field :action, :string
    field :retryable, :boolean, default: false
    field :details, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :channel, Swati.Channels.Channel
    belongs_to :endpoint, Swati.Channels.Endpoint

    timestamps()
  end

  def changeset(call_rejection, attrs) do
    call_rejection
    |> cast(attrs, [
      :tenant_id,
      :channel_id,
      :endpoint_id,
      :provider,
      :provider_call_id,
      :session_external_id,
      :from_address,
      :to_address,
      :direction,
      :reason_code,
      :reason_message,
      :action,
      :retryable,
      :details
    ])
    |> validate_required([:tenant_id, :provider, :reason_code])
  end
end
