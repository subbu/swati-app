defmodule Swati.Tenancy.Membership do
  use Swati.DbSchema

  @roles [:owner, :admin, :agent, :member, :viewer]

  schema "memberships" do
    field :role, Ecto.Enum, values: @roles, default: :member
    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :user, Swati.Accounts.User

    timestamps()
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :tenant_id, :user_id])
    |> validate_required([:role, :tenant_id, :user_id])
    |> unique_constraint(:user_id)
    |> unique_constraint([:tenant_id, :user_id])
  end
end
