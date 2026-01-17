defmodule Swati.Preferences.Preference do
  use Swati.DbSchema

  schema "user_preferences" do
    field :key, :string
    field :value, :map, default: %{}
    field :schema_version, :integer, default: 1

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :user, Swati.Accounts.User

    timestamps()
  end

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [:key, :value, :schema_version])
    |> validate_required([:key, :value, :schema_version])
  end
end
