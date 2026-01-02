defmodule Swati.Telephony do
  import Ecto.Query, warn: false

  alias Swati.Audit
  alias Swati.Repo
  alias Swati.Tenancy

  alias Swati.Telephony.PhoneNumber
  alias Swati.Telephony.Providers.Plivo

  def list_phone_numbers(tenant_id) do
    PhoneNumber
    |> Tenancy.scope(tenant_id)
    |> Repo.all()
  end

  def get_phone_number!(id), do: Repo.get!(PhoneNumber, id)

  def provision_phone_number(tenant_id, attrs, actor) do
    provider = Map.get(attrs, :provider, :plivo)
    e164 = Map.get(attrs, :e164) || Map.get(attrs, "e164")

    with {:ok, provider_meta} <- provider_module(provider).buy_number(e164, attrs),
         {:ok, phone_number} <-
           %PhoneNumber{}
           |> PhoneNumber.changeset(%{
             tenant_id: tenant_id,
             provider: provider,
             e164: e164,
             country: Map.get(attrs, :country) || Map.get(attrs, "country"),
             region: Map.get(attrs, :region) || Map.get(attrs, "region"),
             provider_number_id: Map.get(provider_meta, "id") || Map.get(provider_meta, :id),
             provider_app_id: Map.get(provider_meta, "app_id") || Map.get(provider_meta, :app_id)
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

    with {:ok, _meta} <-
           provider_module(phone_number.provider).configure_inbound(
             provider_meta(phone_number),
             answer_url
           ),
         {:ok, phone_number} <-
           phone_number
           |> PhoneNumber.changeset(%{status: :active, answer_url: answer_url})
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
end
