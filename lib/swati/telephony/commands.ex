defmodule Swati.Telephony.Commands do
  require Logger

  alias Swati.Audit
  alias Swati.Channels
  alias Swati.Repo
  alias Swati.Telephony.AnswerUrl
  alias Swati.Telephony.E164
  alias Swati.Telephony.PhoneNumber
  alias Swati.Telephony.PhoneNumberStatusTransitions
  alias Swati.Telephony.Providers.Plivo

  def search_available_numbers(params, provider \\ :plivo) when is_map(params) do
    provider_module(provider).search_available_numbers(params)
  end

  def provision_phone_number(tenant_id, attrs, actor) do
    provider = Map.get(attrs, :provider, :plivo)
    e164 = Map.get(attrs, :e164) || Map.get(attrs, "e164")
    e164 = if is_binary(e164), do: E164.normalize(e164).normalized, else: e164

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

        _ = Channels.ensure_endpoint_for_phone_number(phone_number)

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

        _ = Channels.ensure_endpoint_for_phone_number(phone_number)

        {:ok, phone_number}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def activate_phone_number(%PhoneNumber{} = phone_number, actor) do
    answer_url = AnswerUrl.answer_url_for(phone_number)

    with :ok <- PhoneNumberStatusTransitions.ensure_allowed(phone_number.status, :active),
         {:ok, meta} <-
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
    with :ok <- PhoneNumberStatusTransitions.ensure_allowed(phone_number.status, :suspended),
         {:ok, phone_number} <-
           phone_number
           |> PhoneNumber.changeset(%{status: :suspended})
           |> Repo.update() do
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
    end
  end

  defp provider_module(:plivo), do: Plivo
  defp provider_module("plivo"), do: Plivo

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
end
