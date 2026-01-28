defmodule Swati.Tenancy.Tenants do
  import Ecto.Query, warn: false

  alias Swati.Accounts.User
  alias Swati.Audit
  alias Swati.Repo
  alias Swati.Tenancy.{Membership, Tenant}

  @doc """
  Returns a slug that is unique for the tenants table.

  We do this upfront to avoid webhook signup failures when a slug already exists.
  """
  def unique_slug(name_or_slug) when is_binary(name_or_slug) do
    base = name_or_slug |> slugify() |> ensure_fallback_slug()
    existing = existing_slug_suffixes(base)

    case existing do
      [] -> base
      suffixes -> "#{base}-#{Enum.max(suffixes) + 1}"
    end
  end

  def create_tenant(attrs, %User{} = owner_user) do
    attrs = normalize_tenant_attrs(attrs)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:tenant, Tenant.changeset(%Tenant{}, attrs))
      |> Ecto.Multi.insert(:membership, fn %{tenant: tenant} ->
        Membership.changeset(%Membership{}, %{
          tenant_id: tenant.id,
          user_id: owner_user.id,
          role: :owner
        })
      end)
      |> Ecto.Multi.run(:audit, fn _repo, %{tenant: tenant} ->
        Audit.log(tenant.id, owner_user.id, "tenant.create", "tenant", tenant.id, attrs, %{})
        {:ok, :logged}
      end)

    case Repo.transaction(multi) do
      {:ok, %{tenant: tenant}} -> {:ok, tenant}
      {:error, _step, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def list_tenants_for_user(%User{id: user_id}) do
    from(t in Tenant,
      join: m in Membership,
      on: m.tenant_id == t.id,
      where: m.user_id == ^user_id,
      order_by: [asc: t.name]
    )
    |> Repo.all()
  end

  def get_tenant!(tenant_id), do: Repo.get!(Tenant, tenant_id)

  def get_tenant(tenant_id), do: Repo.get(Tenant, tenant_id)

  def get_tenant_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Tenant, slug: slug)
  end

  def update_billing_plan(%Tenant{} = tenant, plan_code) when is_binary(plan_code) do
    tenant
    |> Tenant.changeset(%{plan: plan_code})
    |> Repo.update()
  end

  def update_billing_status(%Tenant{} = tenant, status) when is_binary(status) do
    tenant
    |> Tenant.changeset(%{status: status})
    |> Repo.update()
  end

  defp normalize_tenant_attrs(attrs) do
    name = Map.get(attrs, "name") || Map.get(attrs, :name)
    slug = Map.get(attrs, "slug") || Map.get(attrs, :slug)

    slug =
      if is_binary(slug) and slug != "" do
        slug
      else
        unique_slug(name || "")
      end

    attrs
    |> Map.new()
    |> Map.put(:slug, slug)
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

  defp ensure_fallback_slug(""), do: "workspace"
  defp ensure_fallback_slug(slug), do: slug

  defp existing_slug_suffixes(base) do
    pattern = base <> "-%"

    from(t in Tenant,
      where: t.slug == ^base or like(t.slug, ^pattern),
      select: t.slug
    )
    |> Repo.all()
    |> Enum.reduce([], fn slug, acc ->
      cond do
        slug == base -> [0 | acc]
        String.starts_with?(slug, base <> "-") ->
          suffix = String.replace_prefix(slug, base <> "-", "")

          case Integer.parse(suffix) do
            {value, ""} -> [value | acc]
            _ -> acc
          end

        true ->
          acc
      end
    end)
  end
end
