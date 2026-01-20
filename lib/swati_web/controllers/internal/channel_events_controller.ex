defmodule SwatiWeb.Internal.ChannelEventsController do
  use SwatiWeb, :controller

  alias Swati.Channels.Ingestion

  def create(conn, params) do
    case Ingestion.ingest_events(params) do
      {:ok, payload} ->
        json(conn, payload)

      {:error, :endpoint_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "endpoint_not_found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
end
