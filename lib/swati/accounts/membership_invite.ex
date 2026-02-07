defmodule Swati.Accounts.MembershipInvite do
  use Swati.DbSchema

  embedded_schema do
    field :email, :string
    field :role_id, :binary_id
  end

  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:email, :role_id])
    |> validate_required([:email, :role_id])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
  end
end
