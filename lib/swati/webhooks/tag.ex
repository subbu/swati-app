defmodule Swati.Webhooks.Tag do
  use Swati.DbSchema

  @palette_options [
    %{name: "Teal", value: "#0F766E"},
    %{name: "Blue", value: "#2563EB"},
    %{name: "Violet", value: "#7C3AED"},
    %{name: "Pink", value: "#DB2777"},
    %{name: "Red", value: "#DC2626"},
    %{name: "Amber", value: "#D97706"},
    %{name: "Green", value: "#16A34A"},
    %{name: "Slate", value: "#374151"}
  ]

  @palette Enum.map(@palette_options, & &1.value)

  schema "tags" do
    field :name, :string
    field :slug, :string
    field :color, :string

    belongs_to :tenant, Swati.Tenancy.Tenant
    many_to_many :webhooks, Swati.Webhooks.Webhook, join_through: Swati.Webhooks.WebhookTag

    timestamps()
  end

  def palette, do: @palette

  def palette_options, do: @palette_options

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :slug, :color, :tenant_id])
    |> update_change(:name, &String.trim/1)
    |> put_slug()
    |> validate_required([:tenant_id, :name, :slug, :color])
    |> validate_length(:name, min: 2, max: 40)
    |> validate_inclusion(:color, @palette)
    |> unique_constraint(:slug, name: :tags_tenant_id_slug_index)
    |> unique_constraint(:name, name: :tags_tenant_id_lower_name_index)
  end

  defp put_slug(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        slug =
          name
          |> to_string()
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9_-]+/, "-")
          |> String.trim("-")

        put_change(changeset, :slug, slug)
    end
  end
end
