defmodule Swati.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :swati

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  # Add this to lib/swati/release.ex

  def backport_phone_number(e164, country, region, user_id) do
    start_app()

    user_id =
      case Ecto.UUID.cast(user_id) do
        {:ok, uuid} -> uuid
        :error -> raise ArgumentError, "user_id must be a UUID, got: #{inspect(user_id)}"
      end

    %{normalized: normalized, digits: digits} = Swati.Telephony.E164.normalize(e164)

    if normalized == "" do
      raise ArgumentError, "e164 must be a valid phone number, got: #{inspect(e164)}"
    end

    user = Swati.Accounts.get_user!(user_id)
    tenant_id = resolve_tenant_id!(user)

    IO.puts("Backporting phone number: #{normalized}")
    IO.puts("Country: #{country}, Region: #{region}")
    IO.puts("User ID: #{user_id}")
    IO.puts("Tenant ID: #{tenant_id}")

    IO.puts("Found user: #{user.email}")

    attrs =
      %{
        tenant_id: tenant_id,
        provider: :plivo,
        e164: normalized,
        country: country,
        status: :provisioned
      }
      |> maybe_put(:region, region)
      |> maybe_put(:provider_number_id, digits)

    case insert_phone_number(attrs) do
      {:ok, phone_number} ->
        IO.puts("✓ Successfully backported phone number: #{phone_number.e164}")
        {:ok, phone_number}

      {:error, changeset} ->
        IO.puts("✗ Failed to backport phone number")
        IO.inspect(changeset.errors)
        {:error, changeset}
    end
  end

  defp start_app do
    load_app()
    Application.ensure_all_started(:swati)
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.load(@app)
  end

  defp resolve_tenant_id!(user) do
    case Swati.Tenancy.list_tenants_for_user(user) do
      [tenant] ->
        tenant.id

      [] ->
        raise ArgumentError, "user #{user.id} has no tenant; pass tenant_id"

      tenants ->
        tenant_ids = Enum.map(tenants, & &1.id) |> Enum.join(", ")
        raise ArgumentError, "user #{user.id} has multiple tenants (#{tenant_ids})"
    end
  end

  defp insert_phone_number(attrs) do
    %Swati.Telephony.PhoneNumber{}
    |> Swati.Telephony.PhoneNumber.changeset(attrs)
    |> Swati.Repo.insert()
  end

  defp maybe_put(attrs, _key, nil), do: attrs
  defp maybe_put(attrs, _key, ""), do: attrs
  defp maybe_put(attrs, key, value), do: Map.put(attrs, key, value)
end
