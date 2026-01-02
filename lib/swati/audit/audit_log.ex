defmodule Swati.Audit.AuditLog do
  use Swati.DbSchema

  schema "audit_logs" do
    field :action, :string
    field :entity_type, :string
    field :entity_id, :binary_id
    field :changes, :map
    field :ip, :string
    field :user_agent, :string

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :actor, Swati.Accounts.User, foreign_key: :actor_user_id

    timestamps()
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [
      :tenant_id,
      :actor_user_id,
      :action,
      :entity_type,
      :entity_id,
      :changes,
      :ip,
      :user_agent
    ])
    |> validate_required([:tenant_id, :action, :entity_type, :entity_id])
  end
end
