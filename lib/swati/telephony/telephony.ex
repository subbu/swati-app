defmodule Swati.Telephony do
  import Ecto.Query, warn: false

  require Logger

  alias Swati.Audit
  alias Swati.Repo
  alias Swati.Tenancy

  alias Swati.Telephony.PhoneNumber
  alias Swati.Telephony.Providers.Plivo

  def list_phone_numbers(tenant_id) do
    PhoneNumber
    |> Tenancy.scope(tenant_id)
    |> order_by([n], desc: n.inserted_at)
    |> Repo.all()
  end

  def list_phone_numbers(tenant_id, filters) when is_map(filters) do
    filters = normalize_filters(filters)

    PhoneNumber
    |> Tenancy.scope(tenant_id)
    |> apply_search_filter(filters)
    |> apply_status_filter(filters)
    |> apply_agent_filter(filters)
    |> apply_provider_filter(filters)
    |> order_by([n], desc: n.inserted_at)
    |> Repo.all()
  end

  def get_phone_number!(tenant_id, id) do
    Repo.get_by!(PhoneNumber, id: id, tenant_id: tenant_id)
  end

  def search_available_numbers(params, provider \\ :plivo) when is_map(params) do
    provider_module(provider).search_available_numbers(params)
  end

  def get_phone_number!(id), do: Repo.get!(PhoneNumber, id)

  def provision_phone_number(tenant_id, attrs, actor) do
    provider = Map.get(attrs, :provider, :plivo)
    e164 = Map.get(attrs, :e164) || Map.get(attrs, "e164")

    Logger.debug(
      "provision_phone_number start tenant_id=#{tenant_id} provider=#{provider} e164=#{e164} actor_id=#{Map.get(actor, :id)}"
    )

    result =
      with {:ok, provider_meta} <- provider_module(provider).buy_number(e164, attrs),
           {:ok, phone_number} <-
             %PhoneNumber{}
             |> PhoneNumber.changeset(%{
               tenant_id: tenant_id,
               provider: provider,
               e164: e164,
               country: Map.get(attrs, :country) || Map.get(attrs, "country"),
               region: Map.get(attrs, :region) || Map.get(attrs, "region"),
               provider_number_id:
                 Map.get(provider_meta, "id") ||
                   Map.get(provider_meta, :id) ||
                   Map.get(provider_meta, "number") ||
                   Map.get(provider_meta, :number) ||
                   e164,
               provider_app_id:
                 Map.get(provider_meta, "app_id") || Map.get(provider_meta, :app_id)
             })
             |> Repo.insert() do
        Audit.log(
          tenant_id,
          actor.id,
          "phone_number.provision",
          "phone_number",
          phone_number.id,
          attrs,
          %{}
        )

        {:ok, phone_number}
      end

    case result do
      {:ok, phone_number} ->
        Logger.debug(
          "provision_phone_number success id=#{phone_number.id} provider_number_id=#{phone_number.provider_number_id}"
        )

      {:error, reason} ->
        Logger.warning("provision_phone_number failed reason=#{inspect(reason)}")
    end

    result
  end

  def assign_inbound_agent(%PhoneNumber{} = phone_number, agent_id, actor) do
    phone_number
    |> PhoneNumber.changeset(%{inbound_agent_id: agent_id})
    |> Repo.update()
    |> case do
      {:ok, phone_number} ->
        Audit.log(
          phone_number.tenant_id,
          actor.id,
          "phone_number.assign",
          "phone_number",
          phone_number.id,
          %{},
          %{}
        )

        {:ok, phone_number}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def activate_phone_number(%PhoneNumber{} = phone_number, actor) do
    answer_url = answer_url(phone_number)

    with {:ok, meta} <-
           provider_module(phone_number.provider).configure_inbound(
             provider_meta(phone_number),
             answer_url
           ),
         {:ok, phone_number} <-
           phone_number
           |> PhoneNumber.changeset(activate_attrs(answer_url, meta))
           |> Repo.update() do
      Audit.log(
        phone_number.tenant_id,
        actor.id,
        "phone_number.activate",
        "phone_number",
        phone_number.id,
        %{},
        %{}
      )

      {:ok, phone_number}
    end
  end

  def suspend_phone_number(%PhoneNumber{} = phone_number, actor) do
    phone_number
    |> PhoneNumber.changeset(%{status: :suspended})
    |> Repo.update()
    |> case do
      {:ok, phone_number} ->
        Audit.log(
          phone_number.tenant_id,
          actor.id,
          "phone_number.suspend",
          "phone_number",
          phone_number.id,
          %{},
          %{}
        )

        {:ok, phone_number}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp provider_module(:plivo), do: Plivo
  defp provider_module("plivo"), do: Plivo

  defp answer_url(phone_number) do
    base_url = Application.get_env(:swati, :media_gateway_base_url) || ""
    base_url = String.trim_trailing(base_url, "/")
    "#{base_url}/v1/telephony/plivo/answer/#{phone_number.id}"
  end

  defp provider_meta(phone_number) do
    %{
      "provider_number_id" => phone_number.provider_number_id,
      "provider_app_id" => phone_number.provider_app_id
    }
  end

  defp activate_attrs(answer_url, meta) do
    app_id = Map.get(meta, "app_id") || Map.get(meta, :app_id)

    %{status: :active, answer_url: answer_url}
    |> maybe_put_provider_app_id(app_id)
  end

  defp maybe_put_provider_app_id(attrs, nil), do: attrs
  defp maybe_put_provider_app_id(attrs, ""), do: attrs
  defp maybe_put_provider_app_id(attrs, app_id), do: Map.put(attrs, :provider_app_id, app_id)

  defp normalize_filters(filters) do
    filters
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Map.new()
  end

  defp apply_search_filter(query, %{"query" => query_value}) when is_binary(query_value) do
    trimmed = String.trim(query_value)

    if trimmed == "" do
      query
    else
      like = "%#{trimmed}%"

      from(number in query,
        where:
          ilike(number.e164, ^like) or ilike(number.country, ^like) or
            ilike(number.region, ^like)
      )
    end
  end

  defp apply_search_filter(query, _filters), do: query

  defp apply_status_filter(query, %{"status" => status}) when is_binary(status) do
    if status == "" do
      query
    else
      from(number in query, where: number.status == ^status)
    end
  end

  defp apply_status_filter(query, _filters), do: query

  defp apply_agent_filter(query, %{"agent_id" => agent_id}) when is_binary(agent_id) do
    if agent_id == "" do
      query
    else
      from(number in query, where: number.inbound_agent_id == ^agent_id)
    end
  end

  defp apply_agent_filter(query, _filters), do: query

  defp apply_provider_filter(query, %{"provider" => provider}) when is_binary(provider) do
    if provider == "" do
      query
    else
      from(number in query, where: number.provider == ^provider)
    end
  end

  defp apply_provider_filter(query, _filters), do: query
end
