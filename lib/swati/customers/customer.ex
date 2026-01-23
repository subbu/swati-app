defmodule Swati.Customers.Customer do
  use Swati.DbSchema

  @derive {
    Flop.Schema,
    filterable: [:status],
    sortable: [:name, :status, :inserted_at, :updated_at],
    default_order: %{order_by: [:updated_at], order_directions: [:desc]}
  }

  @statuses [:active, :inactive, :blocked]

  schema "customers" do
    field :name, :string
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :primary_email, :string
    field :primary_phone, :string
    field :timezone, :string
    field :language, :string
    field :preferences, :map
    field :metadata, :map

    belongs_to :tenant, Swati.Tenancy.Tenant

    has_many :identities, Swati.Customers.CustomerIdentity

    timestamps()
  end

  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [
      :tenant_id,
      :name,
      :status,
      :primary_email,
      :primary_phone,
      :timezone,
      :language,
      :preferences,
      :metadata
    ])
    |> validate_required([:tenant_id, :status])
  end
end
