defmodule Swati.Approvals.Approval do
  use Swati.DbSchema

  @statuses [:pending, :approved, :rejected, :cancelled]

  schema "approvals" do
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :requested_by_type, :string
    field :requested_by_id, :string
    field :requested_at, :utc_datetime_usec
    field :resolved_at, :utc_datetime_usec
    field :request_payload, :map
    field :decision_payload, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :case, Swati.Cases.Case
    belongs_to :session, Swati.Sessions.Session
    belongs_to :decision_by_user, Swati.Accounts.User

    timestamps()
  end

  def changeset(approval, attrs) do
    approval
    |> cast(attrs, [
      :tenant_id,
      :case_id,
      :session_id,
      :status,
      :requested_by_type,
      :requested_by_id,
      :requested_at,
      :resolved_at,
      :request_payload,
      :decision_payload,
      :decision_by_user_id
    ])
    |> validate_required([:tenant_id, :status, :requested_by_type])
  end
end
