defmodule SwatiWeb.GmailOAuthController do
  use SwatiWeb, :controller

  alias Swati.Channels.Gmail
  require Logger

  @state_salt "gmail_oauth"
  @state_max_age 900

  def connect(conn, _params) do
    tenant = conn.assigns.current_scope.tenant
    state = Phoenix.Token.sign(SwatiWeb.Endpoint, @state_salt, %{"tenant_id" => tenant.id})

    case Gmail.authorization_url(state, redirect_uri(conn)) do
      {:ok, url} ->
        redirect(conn, external: url)

      {:error, reason} ->
        Logger.warning("Gmail OAuth config missing: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Gmail OAuth is not configured.")
        |> redirect(to: ~p"/surfaces")
    end
  end

  def callback(conn, %{"error" => error}) do
    conn
    |> put_flash(:error, "Gmail OAuth failed: #{error}.")
    |> redirect(to: ~p"/surfaces")
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    tenant = conn.assigns.current_scope.tenant

    with {:ok, state_data} <- verify_state(state),
         tenant_id <- Map.get(state_data, "tenant_id") || Map.get(state_data, :tenant_id),
         true <- tenant_id == tenant.id,
         {:ok, _connection} <- Gmail.connect(tenant.id, code, redirect_uri(conn)) do
      conn
      |> put_flash(:info, "Gmail connected.")
      |> redirect(to: ~p"/surfaces")
    else
      reason ->
        Logger.warning("Gmail OAuth connect failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, format_error(reason))
        |> redirect(to: ~p"/surfaces")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Missing OAuth response.")
    |> redirect(to: ~p"/surfaces")
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

    "#{scheme}://#{host}#{port_part}" <> ~p"/channels/gmail/callback"
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

    "Gmail OAuth error (#{status}): #{message}"
  end

  defp format_error(:gmail_profile_missing), do: "Gmail profile missing email."
  defp format_error(:missing_gmail_oauth_config), do: "Gmail OAuth not configured."
  defp format_error(_reason), do: "Unable to connect Gmail."
end
