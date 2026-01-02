defmodule Swati.Accounts.MembershipInvite do
  use Swati.DbSchema

  @roles [:owner, :admin, :agent, :member, :viewer]

  embedded_schema do
    field :email, :string
    field :role, Ecto.Enum, values: @roles, default: :member
  end

  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:email, :role])
    |> validate_required([:email, :role])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
  end
end
