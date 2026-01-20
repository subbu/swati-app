defmodule Swati.Tenancy.Tenant do
  use Swati.DbSchema

  @statuses ["active", "suspended", "trialing"]

  schema "tenants" do
    field :name, :string
    field :slug, :string
    field :timezone, :string, default: "Asia/Kolkata"
    field :formatting, :map, default: %{"locale" => "en-IN", "phone_country" => "IN"}
    field :policy, :map, default: %{}
    field :plan, :string, default: "starter"
    field :status, :string, default: "active"

    has_many :memberships, Swati.Tenancy.Membership

    timestamps()
  end

  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug, :timezone, :formatting, :policy, :plan, :status])
    |> maybe_put_slug()
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:slug, min: 2, max: 120)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:slug)
  end

  defp maybe_put_slug(changeset) do
    name = get_field(changeset, :name)
    slug = get_field(changeset, :slug)

    cond do
      is_binary(slug) and slug != "" ->
        changeset

      is_binary(name) ->
        put_change(changeset, :slug, slugify(name))

      true ->
        changeset
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end
