defmodule Swati.Accounts.Registration do
  alias Swati.Accounts.User
  alias Swati.Audit
  alias Swati.Repo
  alias Swati.Tenancy.{Membership, Tenant}

  def register_user(attrs) do
    tenant_name = Map.get(attrs, "tenant_name") || Map.get(attrs, :tenant_name)
    user_changeset = User.registration_changeset(%User{}, attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:user, user_changeset)
    |> Ecto.Multi.insert(:tenant, Tenant.changeset(%Tenant{}, %{name: tenant_name}))
    |> Ecto.Multi.insert(:membership, fn %{tenant: tenant, user: user} ->
      Membership.changeset(%Membership{}, %{
        tenant_id: tenant.id,
        user_id: user.id,
        role: :owner
      })
    end)
    |> Ecto.Multi.run(:audit, fn _repo, %{tenant: tenant, user: user} ->
      Audit.log(tenant.id, user.id, "tenant.create", "tenant", tenant.id, %{}, %{})
      {:ok, :logged}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :tenant, changeset, _} -> {:error, changeset}
      {:error, :user, changeset, _} -> {:error, changeset}
      {:error, :membership, changeset, _} -> {:error, changeset}
    end
  end

  def change_user_registration(user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(user, attrs, opts)
  end
end
