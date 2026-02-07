defmodule Swati.Tenancy.Roles do
  @moduledoc """
  Context for managing custom roles within a tenant.
  """
  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Tenancy.{Membership, Permissions, Role, RoleTemplates}

  # ── Queries ──────────────────────────────────────────────────────────

  @doc "Lists all roles for a tenant, ordered by system-first then name."
  def list_roles(tenant_id) do
    from(r in Role,
      where: r.tenant_id == ^tenant_id,
      left_join: m in Membership,
      on: m.role_id == r.id,
      group_by: r.id,
      select_merge: %{member_count: count(m.id)},
      order_by: [desc: r.is_system, asc: r.name]
    )
    |> Repo.all()
  end

  @doc "Lists all roles for a tenant with memberships preloaded (includes user data)."
  def list_roles_with_members(tenant_id) do
    from(r in Role,
      where: r.tenant_id == ^tenant_id,
      preload: [memberships: :user],
      order_by: [desc: r.is_system, asc: r.name]
    )
    |> Repo.all()
  end

  @doc "Gets a single role by ID within a tenant."
  def get_role!(tenant_id, role_id) do
    Repo.get_by!(Role, id: role_id, tenant_id: tenant_id)
  end

  @doc "Gets the system Owner role for a tenant."
  def get_system_owner_role!(tenant_id) do
    Repo.get_by!(Role, tenant_id: tenant_id, is_system: true)
  end

  # ── Mutations ────────────────────────────────────────────────────────

  @doc "Creates a new role for the given tenant."
  def create_role(tenant_id, attrs) do
    %Role{}
    |> Role.changeset(Map.put(attrs, "tenant_id", tenant_id))
    |> Repo.insert()
  end

  @doc "Creates a role from a template key for the given tenant."
  def create_from_template(tenant_id, template_key) when is_atom(template_key) do
    case RoleTemplates.get(template_key) do
      nil ->
        {:error, :template_not_found}

      template ->
        create_role(tenant_id, %{
          "name" => template.name,
          "permissions" => Permissions.to_strings(template.permissions),
          "is_system" => template.is_system
        })
    end
  end

  @doc "Updates a role's name and/or permissions."
  def update_role(%Role{} = role, attrs) do
    role
    |> Role.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a role, but only if it has no assigned members and is not a system role.
  """
  def delete_role(%Role{is_system: true}), do: {:error, :system_role}

  def delete_role(%Role{} = role) do
    member_count =
      from(m in Membership, where: m.role_id == ^role.id)
      |> Repo.aggregate(:count)

    if member_count > 0 do
      {:error, :has_members}
    else
      Repo.delete(role)
    end
  end

  # ── Seeding ──────────────────────────────────────────────────────────

  @doc """
  Seeds the default roles for a newly created tenant.
  Returns `{:ok, owner_role}` where owner_role is the system Owner role.
  Called during registration.
  """
  def seed_default_roles(tenant_id) do
    templates = RoleTemplates.default_seed_templates()

    roles =
      Enum.map(templates, fn template ->
        {:ok, role} =
          %Role{}
          |> Role.changeset(%{
            "name" => template.name,
            "permissions" => Permissions.to_strings(template.permissions),
            "is_system" => template.is_system,
            "tenant_id" => tenant_id
          })
          |> Repo.insert()

        role
      end)

    owner_role = Enum.find(roles, & &1.is_system)
    {:ok, owner_role}
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  @doc "Returns a changeset for a new role (for forms)."
  def change_role(%Role{} = role, attrs \\ %{}) do
    Role.changeset(role, attrs)
  end

  @doc "Returns role options as `[{name, id}]` tuples for select inputs."
  def role_options(tenant_id) do
    from(r in Role,
      where: r.tenant_id == ^tenant_id,
      order_by: [desc: r.is_system, asc: r.name],
      select: {r.name, r.id}
    )
    |> Repo.all()
  end
end
