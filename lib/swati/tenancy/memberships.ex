defmodule Swati.Tenancy.Memberships do
  import Ecto.Query, warn: false

  alias Swati.Accounts.{MembershipInvite, Scope, User}
  alias Swati.Repo
  alias Swati.Tenancy.{Membership, Tenant}

  def change_membership_invite(attrs \\ %{}) do
    MembershipInvite.changeset(%MembershipInvite{}, attrs)
  end

  def list_members(%Scope{} = current_scope) do
    with :ok <- authorize(current_scope, :manage_members),
         %Tenant{id: tenant_id} <- current_scope.tenant do
      members =
        from(m in Membership,
          where: m.tenant_id == ^tenant_id,
          join: u in assoc(m, :user),
          preload: [user: u],
          order_by: [asc: u.email]
        )
        |> Repo.all()

      {:ok, members}
    else
      nil -> {:error, :missing_tenant}
      {:error, :unauthorized} -> {:error, :unauthorized}
    end
  end

  def invite_member(%Scope{} = current_scope, attrs, invite_url_fun)
      when is_function(invite_url_fun, 1) do
    with :ok <- authorize(current_scope, :manage_members),
         %Tenant{id: tenant_id} <- current_scope.tenant do
      changeset = MembershipInvite.changeset(%MembershipInvite{}, attrs)

      if changeset.valid? do
        email = Ecto.Changeset.get_field(changeset, :email)
        role = Ecto.Changeset.get_field(changeset, :role)

        case Repo.get_by(User, email: email) |> Repo.preload(:membership) do
          %User{membership: %Membership{tenant_id: ^tenant_id}} ->
            {:error, add_email_error(changeset, "is already a member")}

          %User{membership: %Membership{}} ->
            {:error, add_email_error(changeset, "belongs to another tenant")}

          %User{} = user ->
            create_membership_for_user(user, tenant_id, role, invite_url_fun, changeset)

          nil ->
            create_user_and_membership(email, tenant_id, role, invite_url_fun, changeset)
        end
      else
        {:error, changeset}
      end
    else
      nil -> {:error, :missing_tenant}
      {:error, :unauthorized} -> {:error, :unauthorized}
    end
  end

  def authorized?(%Scope{role: role}, action)
      when action in [:manage_members, :manage_billing] and role in [:owner, :admin],
      do: true

  def authorized?(nil, _action), do: false
  def authorized?(_current_scope, _action), do: false

  def get_membership!(tenant_id, user_id) do
    Repo.get_by!(Membership, tenant_id: tenant_id, user_id: user_id)
  end

  def list_owner_emails(tenant_id) do
    from(m in Membership,
      where: m.tenant_id == ^tenant_id and m.role in [:owner, :admin],
      join: u in assoc(m, :user),
      select: u.email
    )
    |> Repo.all()
  end

  def require_role!(%Membership{role: role}, allowed_roles) when is_list(allowed_roles) do
    if role in allowed_roles do
      :ok
    else
      raise Swati.Tenancy.RoleNotAllowedError
    end
  end

  defp authorize(current_scope, action) do
    if authorized?(current_scope, action), do: :ok, else: {:error, :unauthorized}
  end

  defp create_membership_for_user(user, tenant_id, role, invite_url_fun, changeset) do
    case Repo.insert(
           Membership.changeset(%Membership{}, %{
             user_id: user.id,
             tenant_id: tenant_id,
             role: role
           })
         ) do
      {:ok, membership} ->
        deliver_login_instructions(user, invite_url_fun)
        {:ok, membership}

      {:error, %Ecto.Changeset{} = membership_changeset} ->
        {:error, merge_membership_errors(changeset, membership_changeset)}
    end
  end

  defp create_user_and_membership(email, tenant_id, role, invite_url_fun, changeset) do
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:user, User.email_changeset(%User{}, %{email: email}))
      |> Ecto.Multi.insert(:membership, fn %{user: user} ->
        Membership.changeset(%Membership{}, %{user_id: user.id, tenant_id: tenant_id, role: role})
      end)

    case Repo.transaction(multi) do
      {:ok, %{user: user, membership: membership}} ->
        deliver_login_instructions(user, invite_url_fun)
        {:ok, membership}

      {:error, :user, %Ecto.Changeset{} = user_changeset, _} ->
        {:error, merge_user_errors(changeset, user_changeset)}

      {:error, :membership, %Ecto.Changeset{} = membership_changeset, _} ->
        {:error, merge_membership_errors(changeset, membership_changeset)}
    end
  end

  defp deliver_login_instructions(user, invite_url_fun) do
    Swati.Accounts.Auth.MagicLink.deliver_login_instructions(user, invite_url_fun)
  end

  defp add_email_error(changeset, message) do
    Ecto.Changeset.add_error(changeset, :email, message)
  end

  defp merge_user_errors(changeset, user_changeset) do
    Enum.reduce(user_changeset.errors, changeset, fn {field, {msg, opts}}, acc ->
      Ecto.Changeset.add_error(acc, field, msg, opts)
    end)
  end

  defp merge_membership_errors(changeset, membership_changeset) do
    Enum.reduce(membership_changeset.errors, changeset, fn {field, {msg, opts}}, acc ->
      Ecto.Changeset.add_error(acc, field, msg, opts)
    end)
  end
end
