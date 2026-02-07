defmodule Swati.Tenancy.Role do
  use Swati.DbSchema

  alias Swati.Tenancy.{Membership, Permissions, Tenant}

  schema "roles" do
    field :name, :string
    field :permissions, {:array, :string}, default: []
    field :is_system, :boolean, default: false
    field :member_count, :integer, virtual: true, default: 0

    belongs_to :tenant, Tenant
    has_many :memberships, Membership

    timestamps()
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :permissions, :is_system, :tenant_id])
    |> validate_required([:name, :tenant_id])
    |> validate_length(:name, min: 1, max: 60)
    |> validate_permissions()
    |> unique_constraint([:tenant_id, :name])
  end

  @doc "Changeset for updating a role's name and permissions. System roles cannot be edited."
  def update_changeset(%__MODULE__{is_system: true}, _attrs) do
    %__MODULE__{}
    |> change()
    |> add_error(:is_system, "system roles cannot be modified")
  end

  def update_changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :permissions])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 60)
    |> validate_permissions()
    |> unique_constraint([:tenant_id, :name])
  end

  defp validate_permissions(changeset) do
    validate_change(changeset, :permissions, fn :permissions, perms ->
      invalid =
        perms
        |> Enum.reject(fn str ->
          try do
            atom = String.to_existing_atom(str)
            Permissions.valid?(atom)
          rescue
            ArgumentError -> false
          end
        end)

      case invalid do
        [] -> []
        bad -> [permissions: "contains invalid permissions: #{Enum.join(bad, ", ")}"]
      end
    end)
  end

  @doc "Returns the list of permissions as a MapSet of atoms."
  def permissions_mapset(%__MODULE__{permissions: perms}) do
    Permissions.to_mapset(perms)
  end
end
