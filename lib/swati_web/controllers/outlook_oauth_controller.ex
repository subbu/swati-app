defmodule SwatiWeb.OutlookOAuthController do
  use SwatiWeb, :controller

  alias Swati.Channels.Outlook
  require Logger

  @state_salt "outlook_oauth"
  @state_max_age 900

  def connect(conn, _params) do
    tenant = conn.assigns.current_scope.tenant
    state = Phoenix.Token.sign(SwatiWeb.Endpoint, @state_salt, %{"tenant_id" => tenant.id})

    case Outlook.authorization_url(state, redirect_uri(conn)) do
      {:ok, url} ->
        redirect(conn, external: url)

      {:error, reason} ->
        Logger.warning("Outlook OAuth config missing: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Outlook OAuth is not configured.")
        |> redirect(to: ~p"/channels")
    end
  end

  def callback(conn, %{"error" => error}) do
    conn
    |> put_flash(:error, "Outlook OAuth failed: #{error}.")
    |> redirect(to: ~p"/channels")
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    tenant = conn.assigns.current_scope.tenant

    with {:ok, state_data} <- verify_state(state),
         tenant_id <- Map.get(state_data, "tenant_id") || Map.get(state_data, :tenant_id),
         true <- tenant_id == tenant.id,
         {:ok, _connection} <- Outlook.connect(tenant.id, code, redirect_uri(conn)) do
      conn
      |> put_flash(:info, "Outlook connected.")
      |> redirect(to: ~p"/channels")
    else
      reason ->
        Logger.warning("Outlook OAuth connect failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, format_error(reason))
        |> redirect(to: ~p"/channels")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Missing OAuth response.")
    |> redirect(to: ~p"/channels")
  end

  defp verify_state(state) do
    Phoenix.Token.verify(SwatiWeb.Endpoint, @state_salt, state, max_age: @state_max_age)
  end

  defp redirect_uri(conn) do
    scheme = Atom.to_string(conn.scheme)
    host = conn.host
    port = conn.port

    port_part =
      if port in [80, 443] do
        ""
      else
        ":#{port}"
      end

    "#{scheme}://#{host}#{port_part}" <> ~p"/channels/outlook/callback"
  end

  defp format_error({:error, reason}), do: format_error(reason)

  defp format_error({:http_error, status, body}) do
    message =
      cond do
        is_map(body) ->
          Map.get(body, "error_description") ||
            Map.get(body, "error") ||
            Map.get(body, "message") ||
            inspect(body)

        is_binary(body) ->
          body

        true ->
          inspect(body)
      end

    "Outlook OAuth error (#{status}): #{message}"
  end

  defp format_error(:outlook_profile_missing), do: "Outlook profile missing email."
  defp format_error(:missing_outlook_oauth_config), do: "Outlook OAuth not configured."
  defp format_error(_reason), do: "Unable to connect Outlook."
end
