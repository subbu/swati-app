defmodule SwatiWeb.CallsDownloadController do
  use SwatiWeb, :controller

  alias Swati.Calls
  alias SwatiWeb.CallsLive.Helpers, as: CallsHelpers

  def transcript(conn, %{"id" => id}) do
    with {:ok, call_id} <- parse_call_id(id),
         {:ok, call} <- fetch_call(conn, call_id) do
      url = CallsHelpers.transcript_download_url(call)

      case fetch_remote_response(url) do
        {:ok, response} ->
          send_download_response(conn, response, call_id, :transcript, url)

        :error ->
          case CallsHelpers.transcript_text(call) do
            nil ->
              send_resp(conn, 404, "Not found")

            text ->
              filename = "call-#{call_id}-transcript.txt"

              conn
              |> put_resp_header("content-type", "text/plain")
              |> send_download({:binary, text}, filename: filename)
          end
      end
    else
      _ -> send_resp(conn, 404, "Not found")
    end
  end

  def recording(conn, %{"id" => id}) do
    with {:ok, call_id} <- parse_call_id(id),
         {:ok, call} <- fetch_call(conn, call_id),
         url when is_binary(url) <- CallsHelpers.recording_download_url(call) do
      case fetch_remote_response(url) do
        {:ok, response} -> send_download_response(conn, response, call_id, :recording, url)
        :error -> send_resp(conn, 404, "Not found")
      end
    else
      _ -> send_resp(conn, 404, "Not found")
    end
  end

  defp parse_call_id(id) do
    case CallsHelpers.parse_id(id) do
      nil -> :error
      call_id -> {:ok, call_id}
    end
  end

  defp fetch_call(conn, call_id) do
    tenant_id = conn.assigns.current_scope.tenant.id
    {:ok, Calls.get_call!(tenant_id, call_id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp fetch_remote_response(nil), do: :error

  defp fetch_remote_response(url) do
    case Req.get(url, decode_body: false, http_errors: :return, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: status} = response} when status >= 200 and status < 300 ->
        {:ok, response}

      _ ->
        :error
    end
  end

  defp send_download_response(conn, response, call_id, kind, url) do
    filename = build_filename(call_id, url, response, kind)
    content_type = header_value(response.headers, "content-type") || default_content_type(kind)

    conn
    |> put_resp_header("content-type", content_type)
    |> send_download({:binary, response.body}, filename: filename)
  end

  defp build_filename(call_id, url, response, kind) do
    ext = file_extension(url, response, kind)
    "call-#{call_id}-#{kind}#{ext}"
  end

  defp file_extension(url, response, kind) do
    ext =
      case url || header_value(response.headers, "content-location") do
        nil ->
          ""

        url ->
          url
          |> URI.parse()
          |> Map.get(:path, "")
          |> Path.extname()
      end

    cond do
      ext != "" ->
        ext

      kind == :transcript ->
        ".txt"

      true ->
        ""
    end
  end

  defp default_content_type(:transcript), do: "text/plain"
  defp default_content_type(_kind), do: "application/octet-stream"

  defp header_value(headers, key) do
    key = String.downcase(key)

    Enum.find_value(headers, fn {header_key, value} ->
      if String.downcase(header_key) == key, do: value
    end)
  end
end
