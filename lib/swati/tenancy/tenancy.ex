defmodule Swati.Tenancy do
  import Ecto.Query, warn: false

  alias Swati.Audit
  alias Swati.Repo
  alias Swati.Tenancy.{Membership, Tenant}
  alias Swati.Accounts.User

  def scope(queryable, tenant_id) do
    from(record in queryable, where: record.tenant_id == ^tenant_id)
  end

  def create_tenant(attrs, %User{} = owner_user) do
    attrs = normalize_tenant_attrs(attrs)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:tenant, Tenant.changeset(%Tenant{}, attrs))
      |> Ecto.Multi.insert(:membership, fn %{tenant: tenant} ->
        Membership.changeset(%Membership{}, %{
          tenant_id: tenant.id,
          user_id: owner_user.id,
          role: :owner
        })
      end)
      |> Ecto.Multi.run(:audit, fn _repo, %{tenant: tenant} ->
        Audit.log(tenant.id, owner_user.id, "tenant.create", "tenant", tenant.id, attrs, %{})
        {:ok, :logged}
      end)

    case Repo.transaction(multi) do
      {:ok, %{tenant: tenant}} -> {:ok, tenant}
      {:error, _step, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def list_tenants_for_user(%User{id: user_id}) do
    from(t in Tenant,
      join: m in Membership,
      on: m.tenant_id == t.id,
      where: m.user_id == ^user_id,
      order_by: [asc: t.name]
    )
    |> Repo.all()
  end

  def get_tenant!(tenant_id), do: Repo.get!(Tenant, tenant_id)

  def get_membership!(tenant_id, user_id) do
    Repo.get_by!(Membership, tenant_id: tenant_id, user_id: user_id)
  end

  def require_role!(%Membership{role: role}, allowed_roles) when is_list(allowed_roles) do
    if role in allowed_roles do
      :ok
    else
      raise "role_not_allowed"
    end
  end

  def set_current_tenant(session, tenant_id) do
    Map.put(session, "current_tenant_id", tenant_id)
  end

  defp normalize_tenant_attrs(attrs) do
    name = Map.get(attrs, "name") || Map.get(attrs, :name)
    slug = Map.get(attrs, "slug") || Map.get(attrs, :slug) || slugify(name || "")

    attrs
    |> Map.new()
    |> Map.put(:slug, slug)
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end
