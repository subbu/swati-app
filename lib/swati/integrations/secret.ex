defmodule Swati.Integrations.Secret do
  use Swati.DbSchema

  schema "secrets" do
    field :name, :string
    field :value, Swati.Encrypted.Binary

    belongs_to :tenant, Swati.Tenancy.Tenant

    timestamps()
  end

  def changeset(secret, attrs) do
    secret
    |> cast(attrs, [:tenant_id, :name, :value])
    |> validate_required([:tenant_id, :name, :value])
    |> unique_constraint(:name, name: :secrets_tenant_id_name_index)
  end
end
