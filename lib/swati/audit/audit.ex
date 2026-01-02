defmodule Swati.Audit do
  alias Swati.Audit.AuditLog
  alias Swati.Repo

  def log(tenant_id, actor_user_id, action, entity_type, entity_id, changes, meta \\ %{}) do
    attrs = %{
      tenant_id: tenant_id,
      actor_user_id: actor_user_id,
      action: action,
      entity_type: entity_type,
      entity_id: entity_id,
      changes: changes,
      ip: Map.get(meta, :ip),
      user_agent: Map.get(meta, :user_agent)
    }

    _ = Repo.insert(AuditLog.changeset(%AuditLog{}, attrs))
    :ok
  rescue
    _ -> :ok
  end
end
