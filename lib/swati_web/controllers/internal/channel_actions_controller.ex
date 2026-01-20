defmodule SwatiWeb.Internal.ChannelActionsController do
  use SwatiWeb, :controller

  alias Swati.Channels.Ingestion

  def send_message(conn, params) do
    case Ingestion.request_send(params) do
      {:ok, payload} ->
        json(conn, payload)

      {:error, :session_id_required} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{session_id: ["is required"]}})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
end
