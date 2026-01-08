defmodule Mix.Tasks.Swati.BackportPhoneNumber do
  use Mix.Task

  import Ecto.Query, warn: false

  alias Swati.Accounts.User
  alias Swati.Repo
  alias Swati.Telephony.E164
  alias Swati.Telephony.PhoneNumber
  alias Swati.Tenancy

  @shortdoc "Backport a provisioned phone number into the database"

  @moduledoc """
  Backport a provisioned phone number into the database without calling the provider.

  See docs/mix_tasks.md for usage and examples.

  Required:
    --e164
    --country
    --tenant-id OR (--user-id OR --user-email)

  Optional:
    --region
    --provider (default: plivo)
    --provider-number-id (default: digits from e164)
    --status (default: provisioned)
    --inbound-agent-id
    --update (update if the number already exists)
    --dry-run

  Examples:
    MIX_ENV=prod mix swati.backport_phone_number --e164 +918035739111 --country IN \\
      --user-email subramani.athikunte@gmail.com --region Bangalore
  """

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        switches: [
          e164: :string,
          user_id: :string,
          user_email: :string,
          tenant_id: :string,
          country: :string,
          region: :string,
          provider: :string,
          provider_number_id: :string,
          status: :string,
          inbound_agent_id: :string,
          update: :boolean,
          dry_run: :boolean
        ]
      )

    e164 = required_opt!(opts, :e164)
    country = required_opt!(opts, :country)
    provider = Map.get(opts, :provider, "plivo")
    status = Map.get(opts, :status, "provisioned")

    %{normalized: normalized, digits: digits} = E164.normalize(e164)

    if normalized == "" do
      Mix.raise("Invalid e164 value: #{inspect(e164)}")
    end

    tenant_id =
      case Map.get(opts, :tenant_id) do
        nil ->
          user = resolve_user!(opts)
          resolve_tenant_id!(user)

        value ->
          value
      end

    provider_number_id = Map.get(opts, :provider_number_id, digits)

    if provider_number_id == "" do
      Mix.raise("provider_number_id missing; pass --provider-number-id")
    end

    attrs =
      %{
        tenant_id: tenant_id,
        provider: provider,
        e164: normalized,
        country: country,
        status: status,
        provider_number_id: provider_number_id
      }
      |> maybe_put(:region, Map.get(opts, :region))
      |> maybe_put(:inbound_agent_id, Map.get(opts, :inbound_agent_id))

    if Map.get(opts, :dry_run, false) do
      Mix.shell().info("dry-run attrs=#{inspect(attrs)}")
      exit({:shutdown, 0})
    end

    existing = Repo.get_by(PhoneNumber, e164: normalized)

    case {existing, Map.get(opts, :update, false)} do
      {nil, _} ->
        phone_number = insert_phone_number!(attrs)
        Mix.shell().info("phone_number created id=#{phone_number.id} e164=#{phone_number.e164}")

      {%PhoneNumber{} = record, true} ->
        phone_number = update_phone_number!(record, attrs)
        Mix.shell().info("phone_number updated id=#{phone_number.id} e164=#{phone_number.e164}")

      {%PhoneNumber{} = record, false} ->
        Mix.raise(
          "phone_number exists id=#{record.id} e164=#{record.e164}; pass --update to modify"
        )
    end
  end

  defp required_opt!(opts, key) do
    case Map.get(opts, key) do
      nil -> Mix.raise("missing required option --#{key}")
      value -> value
    end
  end

  defp resolve_user!(opts) do
    if Map.has_key?(opts, :user_id) and Map.has_key?(opts, :user_email) do
      Mix.raise("use only one of --user-id or --user-email")
    end

    cond do
      Map.get(opts, :user_id) ->
        resolve_user_by_id!(Map.get(opts, :user_id))

      Map.get(opts, :user_email) ->
        Repo.get_by(User, email: Map.get(opts, :user_email)) ||
          Mix.raise("user not found for email=#{Map.get(opts, :user_email)}")

      true ->
        Mix.raise("missing --tenant-id or --user-id or --user-email")
    end
  end

  defp resolve_user_by_id!(value) do
    case Integer.parse(value) do
      {index, ""} when index > 0 ->
        user =
          User
          |> order_by([u], asc: u.inserted_at)
          |> offset(^(index - 1))
          |> limit(1)
          |> Repo.one()

        user || Mix.raise("user index #{index} not found")

      _ ->
        Repo.get(User, value) || Mix.raise("user not found for id=#{value}")
    end
  end

  defp resolve_tenant_id!(%User{} = user) do
    case Tenancy.list_tenants_for_user(user) do
      [tenant] ->
        tenant.id

      [] ->
        Mix.raise("user #{user.id} has no tenant; pass --tenant-id")

      tenants ->
        tenant_ids = Enum.map(tenants, & &1.id) |> Enum.join(", ")
        Mix.raise("user #{user.id} has multiple tenants (#{tenant_ids}); pass --tenant-id")
    end
  end

  defp insert_phone_number!(attrs) do
    %PhoneNumber{}
    |> PhoneNumber.changeset(attrs)
    |> Repo.insert!()
  end

  defp update_phone_number!(%PhoneNumber{} = record, attrs) do
    record
    |> PhoneNumber.changeset(attrs)
    |> Repo.update!()
  end

  defp maybe_put(attrs, _key, nil), do: attrs
  defp maybe_put(attrs, _key, ""), do: attrs
  defp maybe_put(attrs, key, value), do: Map.put(attrs, key, value)
end
