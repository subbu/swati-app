defmodule Swati.Integrations.Integration do
  use Swati.DbSchema

  @types [:mcp_streamable_http]
  @auth_types [:bearer, :none]
  @statuses [:active, :disabled]

  schema "integrations" do
    field :type, Ecto.Enum, values: @types, default: :mcp_streamable_http
    field :name, :string
    field :endpoint_url, :string
    field :origin, :string, default: "https://customer.example.com"
    field :protocol_version, :string, default: "2025-06-18"
    field :timeout_secs, :integer, default: 15
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :allowed_tools, Swati.Types.StringList, default: []
    field :tool_prefix, :string
    field :auth_type, Ecto.Enum, values: @auth_types, default: :none
    field :last_tested_at, :utc_datetime_usec
    field :last_test_status, :string
    field :last_test_error, :string

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :auth_secret, Swati.Integrations.Secret

    timestamps()
  end

  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [
      :tenant_id,
      :type,
      :name,
      :endpoint_url,
      :origin,
      :protocol_version,
      :timeout_secs,
      :status,
      :allowed_tools,
      :tool_prefix,
      :auth_type,
      :auth_secret_id,
      :last_tested_at,
      :last_test_status,
      :last_test_error
    ])
    |> validate_required([
      :tenant_id,
      :type,
      :name,
      :endpoint_url,
      :origin,
      :protocol_version,
      :timeout_secs,
      :status,
      :allowed_tools,
      :auth_type
    ])
    |> validate_number(:timeout_secs, greater_than: 0)
    |> unique_constraint(:name, name: :integrations_tenant_id_name_index)
  end
end
