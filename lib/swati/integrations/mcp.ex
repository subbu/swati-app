defmodule Swati.Integrations.MCP do
  alias Swati.Integrations.Integration
  alias Swati.Integrations.MCP.ClientReq
  alias Swati.Integrations.Secrets
  alias Swati.Repo

  def test_integration(%Integration{type: :mcp_streamable_http} = integration) do
    case fetch_tools(integration) do
      {:ok, tools} ->
        case update_test_status(integration, {:ok, "success", nil}) do
          {:ok, integration} -> {:ok, integration, tools}
          {:error, changeset} -> {:error, changeset}
        end

      {:error, error} ->
        case update_test_status(integration, {:error, "error", error}) do
          {:ok, _integration} -> {:error, error}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def test_integration(%Integration{} = integration) do
    case update_test_status(integration, {:error, "error", "Unsupported integration type"}) do
      {:ok, _integration} -> {:error, "Unsupported integration type"}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def fetch_tools(%Integration{type: :mcp_streamable_http} = integration) do
    with {:ok, session_id} <- mcp_initialize(integration),
         :ok <- mcp_initialized(integration, session_id),
         {:ok, tools} <- mcp_list_tools(integration, session_id) do
      {:ok, tools}
    end
  end

  def fetch_tools(%Integration{}) do
    {:error, "Unsupported integration type"}
  end

  defp update_test_status(integration, {status, label, error}) do
    changes = %{
      last_tested_at: DateTime.utc_now(),
      last_test_status: label,
      last_test_error: error
    }

    integration
    |> Ecto.Changeset.change(changes)
    |> Repo.update()
    |> case do
      {:ok, integration} -> {status, integration}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp mcp_initialize(integration) do
    payload = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => %{
        "protocolVersion" => integration.protocol_version || "2025-06-18",
        "capabilities" => %{},
        "clientInfo" => %{"name" => "Swati", "version" => "dev"}
      }
    }

    case mcp_request(integration, payload, nil) do
      {:ok, %Req.Response{status: status, headers: headers}} when status in 200..299 ->
        case header_value(headers, "mcp-session-id") do
          nil -> {:error, "Missing MCP session id"}
          session_id -> {:ok, session_id}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, response_error(body, status)}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  defp mcp_initialized(integration, session_id) do
    payload = %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}

    case mcp_request(integration, payload, session_id) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, response_error(body, status)}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  defp mcp_list_tools(integration, session_id) do
    payload = %{"jsonrpc" => "2.0", "id" => 2, "method" => "tools/list"}

    case mcp_request(integration, payload, session_id) do
      {:ok, %Req.Response{status: status, body: %{"result" => %{"tools" => tools}}}}
      when status in 200..299 ->
        {:ok, tools}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, response_error(body, status)}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  defp mcp_request(integration, payload, session_id) do
    headers = mcp_headers(integration, session_id)
    timeout = (integration.timeout_secs || 15) * 1_000

    client().request(
      method: :post,
      url: integration.endpoint_url,
      headers: headers,
      json: payload,
      receive_timeout: timeout
    )
  end

  defp mcp_headers(integration, session_id) do
    base_headers =
      [{"accept", "application/json, text/event-stream"}, {"content-type", "application/json"}] ++
        Secrets.auth_headers(integration)

    case session_id do
      nil -> base_headers
      value -> [{"mcp-session-id", value} | base_headers]
    end
  end

  defp header_value(headers, key) do
    target = String.downcase(key)

    Enum.find_value(headers, fn {name, value} ->
      if String.downcase(to_string(name)) == target, do: value
    end)
  end

  defp response_error(%{"error" => %{"data" => %{"message" => message}}}, _status), do: message
  defp response_error(%{"error" => %{"message" => message}}, _status), do: message
  defp response_error(_body, status), do: "Unexpected status: #{status}"

  defp client do
    Application.get_env(:swati, :mcp_client, ClientReq)
  end
end
