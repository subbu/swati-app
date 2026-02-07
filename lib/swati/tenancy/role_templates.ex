defmodule Swati.Tenancy.RoleTemplates do
  @moduledoc """
  Pre-defined role templates that admins can use to quickly create roles.

  Each template defines a name, description (shown in the picker), and a set
  of default permissions. The Owner template is special — it is seeded as
  a system role (is_system: true) and gets ALL permissions automatically.
  """

  alias Swati.Tenancy.Permissions

  @templates [
    %{
      key: :owner,
      name: "Owner",
      description: "Full access to everything, including billing. Cannot be deleted.",
      is_system: true,
      permissions: Permissions.all()
    },
    %{
      key: :admin,
      name: "Admin",
      description: "Full access except billing and payments.",
      is_system: false,
      permissions:
        Permissions.all()
        |> Enum.reject(&(&1 == :manage_billing))
    },
    %{
      key: :manager,
      name: "Manager",
      description: "Manage cases, customers, members, and view everything.",
      is_system: false,
      permissions: [
        :view_dashboard,
        :view_sessions,
        :view_cases,
        :view_customers,
        :view_billing,
        :manage_cases,
        :assign_cases,
        :update_case_status,
        :manage_customers,
        :manage_members,
        :manage_roles,
        :manage_settings
      ]
    },
    %{
      key: :receptionist,
      name: "Receptionist",
      description: "Handle cases and customers, view conversations.",
      is_system: false,
      permissions: [
        :view_dashboard,
        :view_sessions,
        :view_cases,
        :view_customers,
        :manage_cases,
        :assign_cases,
        :update_case_status,
        :manage_customers
      ]
    },
    %{
      key: :doctor,
      name: "Doctor",
      description: "View and update cases assigned to them.",
      is_system: false,
      permissions: [
        :view_dashboard,
        :view_sessions,
        :view_cases,
        :view_customers,
        :update_case_status
      ]
    },
    %{
      key: :technician,
      name: "Technician",
      description: "View cases and update status. For mechanics, lab techs, etc.",
      is_system: false,
      permissions: [
        :view_dashboard,
        :view_cases,
        :update_case_status
      ]
    },
    %{
      key: :billing_admin,
      name: "Billing Admin",
      description: "Manage billing and payments only.",
      is_system: false,
      permissions: [
        :view_dashboard,
        :view_billing,
        :manage_billing
      ]
    },
    %{
      key: :agent_builder,
      name: "Agent Builder",
      description: "Build and configure AI agents, channels, and integrations.",
      is_system: false,
      permissions: [
        :view_dashboard,
        :view_sessions,
        :manage_agents,
        :manage_channels,
        :manage_integrations,
        :manage_webhooks,
        :manage_trust
      ]
    }
  ]

  @doc "Returns all available role templates."
  def all, do: @templates

  @doc "Returns a single template by its key atom."
  def get(key) when is_atom(key) do
    Enum.find(@templates, &(&1.key == key))
  end

  @doc "Returns only the non-system templates (for the 'create from template' picker)."
  def selectable do
    Enum.reject(@templates, & &1.is_system)
  end

  @doc "Returns the templates that are seeded on tenant creation."
  def default_seed_templates do
    # Seed Owner + Admin by default. Admins can add more from templates later.
    Enum.filter(@templates, &(&1.key in [:owner, :admin]))
  end
end
