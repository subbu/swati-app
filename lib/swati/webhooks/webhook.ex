defmodule Swati.Webhooks.Webhook do
  use Swati.DbSchema

  @methods [:get, :post, :put, :patch, :delete]
  @auth_types [:bearer, :none]
  @statuses [:active, :disabled]

  schema "webhooks" do
    field :name, :string
    field :tool_name, :string
    field :description, :string
    field :endpoint_url, :string
    field :http_method, Ecto.Enum, values: @methods, default: :post
    field :timeout_secs, :integer, default: 15
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :headers, :map, default: %{}
    field :input_schema, :map, default: %{}
    field :sample_payload, :map
    field :auth_type, Ecto.Enum, values: @auth_types, default: :none
    field :last_tested_at, :utc_datetime_usec
    field :last_test_status, :string
    field :last_test_error, :string

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :auth_secret, Swati.Integrations.Secret

    many_to_many :tags, Swati.Webhooks.Tag,
      join_through: Swati.Webhooks.WebhookTag,
      on_replace: :delete

    timestamps()
  end

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [
      :name,
      :tool_name,
      :description,
      :endpoint_url,
      :http_method,
      :timeout_secs,
      :status,
      :headers,
      :input_schema,
      :sample_payload,
      :auth_type,
      :auth_secret_id,
      :last_tested_at,
      :last_test_status,
      :last_test_error
    ])
    |> maybe_put_tenant_id(attrs)
    |> validate_required([
      :tenant_id,
      :name,
      :tool_name,
      :endpoint_url,
      :http_method,
      :timeout_secs,
      :status,
      :headers,
      :input_schema,
      :auth_type
    ])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:tool_name, min: 2, max: 120)
    |> validate_format(:tool_name, ~r/^[a-z0-9_-]+$/)
    |> validate_number(:timeout_secs, greater_than: 0)
    |> unique_constraint(:name, name: :webhooks_tenant_id_name_index)
    |> unique_constraint(:tool_name, name: :webhooks_tenant_id_tool_name_index)
  end

  defp maybe_put_tenant_id(changeset, attrs) do
    case Map.get(attrs, "tenant_id") || Map.get(attrs, :tenant_id) do
      nil -> changeset
      tenant_id -> Ecto.Changeset.put_change(changeset, :tenant_id, tenant_id)
    end
  end
end
