defmodule Swati.Tools.Tool do
  use Swati.DbSchema

  alias Swati.Tools.Risk

  @statuses ["active", "disabled", "archived"]

  schema "tools" do
    field :name, :string
    field :description, :string
    field :origin, :string, default: "manual"
    field :status, :string, default: "active"
    field :risk, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :tenant, Swati.Tenancy.Tenant

    timestamps()
  end

  def changeset(tool, attrs) do
    tool
    |> cast(attrs, [:tenant_id, :name, :description, :origin, :status, :risk, :metadata])
    |> validate_required([:tenant_id, :name, :origin, :status, :risk])
    |> validate_inclusion(:status, @statuses)
    |> normalize_risk()
    |> unique_constraint(:name, name: :tools_tenant_id_name_index)
  end

  defp normalize_risk(changeset) do
    risk = get_field(changeset, :risk)
    put_change(changeset, :risk, Risk.normalize(risk))
  end
end
