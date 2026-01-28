defmodule Swati.Tenancy do
  import Ecto.Query, warn: false

  alias Swati.Accounts.User
  alias Swati.Tenancy.Memberships
  alias Swati.Tenancy.Tenant
  alias Swati.Tenancy.Tenants

  def scope(queryable, tenant_id) do
    from(record in queryable, where: record.tenant_id == ^tenant_id)
  end

  def create_tenant(attrs, %User{} = owner_user) do
    Tenants.create_tenant(attrs, owner_user)
  end

  def list_tenants_for_user(%User{} = user) do
    Tenants.list_tenants_for_user(user)
  end

  def get_tenant!(tenant_id) do
    Tenants.get_tenant!(tenant_id)
  end

  def get_tenant_by_slug(slug) do
    Tenants.get_tenant_by_slug(slug)
  end

  def update_billing_plan(%Tenant{} = tenant, plan_code) do
    Tenants.update_billing_plan(tenant, plan_code)
  end

  def update_billing_status(%Tenant{} = tenant, status) do
    Tenants.update_billing_status(tenant, status)
  end

  def get_membership!(tenant_id, user_id) do
    Memberships.get_membership!(tenant_id, user_id)
  end

  def require_role!(membership, allowed_roles) when is_list(allowed_roles) do
    Memberships.require_role!(membership, allowed_roles)
  end

  def set_current_tenant(session, tenant_id) do
    Map.put(session, "current_tenant_id", tenant_id)
  end
end
