defmodule Swati.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Swati.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias Swati.Accounts.User
  alias Swati.Tenancy.{Permissions, Role}

  defstruct user: nil, tenant: nil, role: nil, permissions: MapSet.new()

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    tenant =
      case user.tenant do
        %Ecto.Association.NotLoaded{} -> nil
        tenant -> tenant
      end

    {role, permissions} =
      case user.membership do
        %Ecto.Association.NotLoaded{} ->
          {nil, MapSet.new()}

        nil ->
          {nil, MapSet.new()}

        %{role: %Role{} = role} ->
          {role, Permissions.to_mapset(role.permissions)}

        %{role: %Ecto.Association.NotLoaded{}} ->
          {nil, MapSet.new()}

        _membership ->
          {nil, MapSet.new()}
      end

    %__MODULE__{user: user, tenant: tenant, role: role, permissions: permissions}
  end

  def for_user(nil), do: nil

  @doc """
  Returns whether the scope has permission to perform the given action.
  O(1) lookup against a preloaded MapSet.
  """
  def can?(%__MODULE__{permissions: permissions}, action) when is_atom(action) do
    MapSet.member?(permissions, action)
  end

  def can?(nil, _action), do: false
end
