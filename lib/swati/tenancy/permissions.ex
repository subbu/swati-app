defmodule Swati.Tenancy.Permissions do
  @moduledoc """
  Canonical permission definitions for the custom roles system.

  Permissions are plain atoms stored as strings in a JSONB array on each role.
  This module provides the single source of truth for all valid permissions,
  their human-readable labels, and their UI groupings.
  """

  @groups [
    %{
      key: :viewing,
      label: "Viewing",
      description: "Control what sections of the app are visible",
      permissions: [
        %{key: :view_dashboard, label: "Dashboard"},
        %{key: :view_sessions, label: "Conversations"},
        %{key: :view_cases, label: "Cases"},
        %{key: :view_customers, label: "Customers"},
        %{key: :view_billing, label: "Billing"}
      ]
    },
    %{
      key: :case_management,
      label: "Case management",
      description: "Work with cases and customers",
      permissions: [
        %{key: :manage_cases, label: "Create & edit cases"},
        %{key: :assign_cases, label: "Assign cases to members"},
        %{key: :update_case_status, label: "Change case status"},
        %{key: :manage_customers, label: "Create & edit customers"}
      ]
    },
    %{
      key: :platform_config,
      label: "Platform configuration",
      description: "Set up AI agents, channels, and integrations",
      permissions: [
        %{key: :manage_agents, label: "AI agents"},
        %{key: :manage_channels, label: "Endpoints & surfaces"},
        %{key: :manage_integrations, label: "Integrations & webhooks"},
        %{key: :manage_webhooks, label: "Webhooks"},
        %{key: :manage_trust, label: "Trust console"}
      ]
    },
    %{
      key: :organization,
      label: "Organization",
      description: "Manage team members, roles, billing, and settings",
      permissions: [
        %{key: :manage_members, label: "Manage members"},
        %{key: :manage_roles, label: "Manage roles"},
        %{key: :manage_billing, label: "Billing & payments"},
        %{key: :manage_settings, label: "Workspace settings"}
      ]
    }
  ]

  @all_permissions @groups
                   |> Enum.flat_map(& &1.permissions)
                   |> Enum.map(& &1.key)

  @doc "Returns all permission groups with their permissions for UI rendering."
  def groups, do: @groups

  @doc "Returns the flat list of all valid permission atoms."
  def all, do: @all_permissions

  @doc "Returns true if the given atom is a valid permission."
  def valid?(permission) when is_atom(permission), do: permission in @all_permissions
  def valid?(_), do: false

  @doc "Returns the human-readable label for a permission atom."
  def label(permission) when is_atom(permission) do
    @groups
    |> Enum.flat_map(& &1.permissions)
    |> Enum.find(&(&1.key == permission))
    |> case do
      %{label: label} -> label
      nil -> permission |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
    end
  end

  @doc """
  Converts a list of permission strings (from DB) to a MapSet of atoms.
  Ignores any strings that don't correspond to valid permissions.
  """
  def to_mapset(permission_strings) when is_list(permission_strings) do
    permission_strings
    |> Enum.reduce(MapSet.new(), fn str, acc ->
      try do
        atom = String.to_existing_atom(str)
        if valid?(atom), do: MapSet.put(acc, atom), else: acc
      rescue
        ArgumentError -> acc
      end
    end)
  end

  def to_mapset(_), do: MapSet.new()

  @doc "Converts a list of permission atoms to a list of strings for DB storage."
  def to_strings(permissions) when is_list(permissions) do
    permissions
    |> Enum.filter(&valid?/1)
    |> Enum.map(&Atom.to_string/1)
    |> Enum.sort()
  end

  def to_strings(%MapSet{} = permissions) do
    permissions |> MapSet.to_list() |> to_strings()
  end
end
