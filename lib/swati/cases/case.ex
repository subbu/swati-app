defmodule Swati.Cases.Case do
  use Swati.DbSchema

  @statuses [:new, :triage, :in_progress, :waiting_on_customer, :resolved, :closed]
  @priorities [:low, :normal, :high, :urgent]

  schema "cases" do
    field :status, Ecto.Enum, values: @statuses, default: :new
    field :priority, Ecto.Enum, values: @priorities, default: :normal
    field :category, :string
    field :title, :string
    field :summary, :string
    field :memory, :map
    field :opened_at, :utc_datetime_usec
    field :resolved_at, :utc_datetime_usec
    field :closed_at, :utc_datetime_usec
    field :sla_due_at, :utc_datetime_usec
    field :metadata, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :customer, Swati.Customers.Customer
    belongs_to :assigned_agent, Swati.Agents.Agent
    belongs_to :assigned_user, Swati.Accounts.User

    has_many :sessions, Swati.Sessions.Session

    timestamps()
  end

  def changeset(case_record, attrs) do
    case_record
    |> cast(attrs, [
      :tenant_id,
      :customer_id,
      :assigned_agent_id,
      :assigned_user_id,
      :status,
      :priority,
      :category,
      :title,
      :summary,
      :memory,
      :opened_at,
      :resolved_at,
      :closed_at,
      :sla_due_at,
      :metadata
    ])
    |> validate_required([:tenant_id, :status, :priority])
  end
end
