defmodule Swati.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Swati.Repo

  alias Swati.Accounts.{MembershipInvite, Scope, User, UserToken, UserNotifier}
  alias Swati.Audit
  alias Swati.Tenancy.{Membership, Tenant}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
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

  @doc """
  Returns an `%Ecto.Changeset{}` for inviting a member to a tenant.
  """
  def change_membership_invite(attrs \\ %{}) do
    MembershipInvite.changeset(%MembershipInvite{}, attrs)
  end

  @doc """
  Returns members for the current tenant.
  """
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

  @doc """
  Invites a member to the current tenant.
  """
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

  @doc """
  Returns whether the current scope is allowed to perform an action.
  """
  def authorized?(%Scope{role: role}, :manage_members) when role in [:owner, :admin], do: true
  def authorized?(nil, _action), do: false
  def authorized?(_current_scope, _action), do: false

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

  @doc """
  Returns an `%Ecto.Changeset{}` for registering a user with a tenant.
  """
  def change_user_registration(user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(user, attrs, opts)
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `Swati.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `Swati.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    case Repo.one(query) do
      {user, token_inserted_at} ->
        {Repo.preload(user, [:membership, :tenant]), token_inserted_at}

      nil ->
        nil
    end
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
