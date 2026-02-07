defmodule Swati.Tenancy.Membership do
  use Swati.DbSchema

  @roles [:owner, :admin, :staff, :member, :viewer]

  schema "memberships" do
    field :role, Ecto.Enum, values: @roles, default: :member
    field :display_name, :string
    field :title, :string
    field :phone, :string

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :user, Swati.Accounts.User

    timestamps()
  end

  def roles, do: @roles

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :tenant_id, :user_id, :display_name, :title, :phone])
    |> validate_required([:role, :tenant_id, :user_id])
    |> validate_length(:display_name, max: 120)
    |> validate_length(:title, max: 120)
    |> validate_length(:phone, max: 30)
    |> unique_constraint(:user_id)
    |> unique_constraint([:tenant_id, :user_id])
  end

  def profile_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:display_name, :title, :phone])
    |> validate_length(:display_name, max: 120)
    |> validate_length(:title, max: 120)
    |> validate_length(:phone, max: 30)
  end

  @doc """
  Returns the display name for a membership, falling back to the user's email.
  """
  def display_name(%__MODULE__{display_name: name}) when is_binary(name) and name != "", do: name
  def display_name(%__MODULE__{user: %{email: email}}), do: email
  def display_name(_), do: "Unknown"
end
