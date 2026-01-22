defmodule SwatiWeb.Internal.RuntimeRejectionsController do
  use SwatiWeb, :controller

  alias Swati.Calls
  alias Swati.Channels

  def create(conn, params) do
    {endpoint, channel} = resolve_endpoint(params)
    tenant_id = param(params, [:tenant_id]) || (endpoint && endpoint.tenant_id)

    if is_nil(tenant_id) do
      conn
      |> put_status(:not_found)
      |> json(%{error: "endpoint_not_found"})
    else
      attrs = build_attrs(params, tenant_id, endpoint, channel)

      case Calls.create_call_rejection(attrs) do
        {:ok, rejection} ->
          conn
          |> put_status(:created)
          |> json(%{id: rejection.id})

        {:error, changeset} ->
          errors =
            Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
              SwatiWeb.CoreComponents.translate_error({message, opts})
            end)

          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: errors})
      end
    end
  end

  defp build_attrs(params, tenant_id, endpoint, channel) do
    error = param(params, [:error]) || %{}

    %{
      tenant_id: tenant_id,
      channel_id: param(params, [:channel_id]) || (channel && channel.id),
      endpoint_id: param(params, [:endpoint_id]) || (endpoint && endpoint.id),
      provider: param(params, [:provider]) || "unknown",
      provider_call_id: param(params, [:provider_call_id]),
      session_external_id: param(params, [:session_external_id]),
      from_address: param(params, [:from_address]),
      to_address: param(params, [:to_address]) || param(params, [:endpoint_address]),
      direction: param(params, [:direction]),
      reason_code:
        error_field(error, :code) ||
          param(params, [:reason_code]) ||
          "runtime_rejected",
      reason_message:
        error_field(error, :message) ||
          param(params, [:reason_message]),
      action:
        error_field(error, :action) ||
          param(params, [:action]),
      retryable: normalize_bool(error_field(error, :retryable) || param(params, [:retryable])),
      details: normalize_details(error)
    }
  end

  defp resolve_endpoint(params) do
    address = param(params, [:endpoint_address])
    channel_key = param(params, [:channel_key])
    channel_type = param(params, [:channel_type])

    endpoint =
      cond do
        is_binary(channel_key) and is_binary(address) ->
          Channels.get_endpoint_by_channel_key_any_status(channel_key, address)

        is_binary(channel_type) and is_binary(address) ->
          Channels.get_endpoint_by_channel_type_any_status(channel_type, address)

        true ->
          nil
      end

    channel = endpoint && endpoint.channel
    {endpoint, channel}
  end

  defp param(params, keys) do
    Enum.find_value(keys, fn key ->
      Map.get(params, key) || Map.get(params, to_string(key))
    end)
  end

  defp error_field(error, key) when is_map(error) do
    Map.get(error, key) || Map.get(error, to_string(key))
  end

  defp error_field(_error, _key), do: nil

  defp normalize_bool(value) when is_boolean(value), do: value
  defp normalize_bool(value) when is_binary(value), do: value in ["true", "1", "yes", "y"]
  defp normalize_bool(value) when is_integer(value), do: value == 1
  defp normalize_bool(_value), do: false

  defp normalize_details(error) when is_map(error) do
    details = Map.get(error, "details") || Map.get(error, :details)

    if is_map(details) do
      details
    else
      Map.drop(error, ["code", "message", "action", "retryable"])
    end
  end

  defp normalize_details(_error), do: nil
end
