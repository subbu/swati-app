defmodule Swati.Channels.WhatsApp.TemplateMessage do
  use Swati.DbSchema

  @statuses ~w(queued sent delivered read failed warning unknown)

  schema "whatsapp_template_messages" do
    field :waba_id, :string
    field :phone_number_id, :string
    field :recipient, :string
    field :template_name, :string
    field :template_language, :string
    field :meta_message_id, :string
    field :status, :string, default: "queued"
    field :status_events, :map, default: %{"events" => []}
    field :provider_response, :map, default: %{}
    field :template_payload, :map, default: %{}
    field :sent_at, :utc_datetime_usec
    field :delivered_at, :utc_datetime_usec
    field :read_at, :utc_datetime_usec
    field :failed_at, :utc_datetime_usec

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :connection, Swati.Channels.ChannelConnection

    timestamps()
  end

  def statuses, do: @statuses

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :tenant_id,
      :connection_id,
      :waba_id,
      :phone_number_id,
      :recipient,
      :template_name,
      :template_language,
      :meta_message_id,
      :status,
      :status_events,
      :provider_response,
      :template_payload,
      :sent_at,
      :delivered_at,
      :read_at,
      :failed_at
    ])
    |> validate_required([
      :tenant_id,
      :connection_id,
      :recipient,
      :template_name,
      :template_language,
      :status
    ])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:meta_message_id,
      name: :whatsapp_template_messages_tenant_id_meta_message_id_index
    )
  end
end
